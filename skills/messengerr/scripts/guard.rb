#!/usr/bin/env ruby
# guard.rb — PreToolUse hook for the messengerr skill.
#
# Reads Claude Code's hook JSON on stdin and exits 2 (block; stderr is shown to
# Claude) when a tool call would
#   * send real messages:  `messengerr send` without a standalone --dry-run,
#                          --help or -h argument, or with --allow-non-interactive;
#   * handle credentials:  `messengerr credentials setup|delete`, or touch the
#                          messengerr config directory (credentials + master key)
#                          through Bash, Read, Grep, Glob, Edit or Write.
# Anything else exits 0 silently.
#
# HONEST LIMITS. This is a seatbelt, not a security boundary. A hook that crashes
# or exits with any code other than 2 lets the call through (it "fails open"), and
# shell indirection can always hide a command from a static check. The CLI's own
# "a real send needs an interactive terminal" check is the backstop.
#
# It parses the command like a shell would (quotes, ; && || | & newlines, $( ),
# backticks, comments, line continuations, simple variables, bash -c / eval) rather
# than matching substrings, so `--html`, `--ledger my-holiday.jsonl` or a comment
# like `# --dry-run` cannot be mistaken for a safe flag.
require "json"

module MessengerrGuard
  SAFE_SEND_FLAGS = %w[--dry-run --help -h].freeze
  SHELLS = %w[bash sh zsh dash ksh fish eval source .].freeze
  SCRIPTING = %w[ruby python python3 node perl php lua osascript irb pry].freeze
  READERS = %w[grep egrep fgrep rg ag ack find tar zip rsync cp scp tree].freeze
  ENV_DUMPERS = %w[env printenv export set declare typeset compgen].freeze
  MAX_DEPTH = 6
  MAX_FILE = 64 * 1024

  module_function

  # → nil when the payload is fine, otherwise the reason string to show Claude.
  def check(payload, env: ENV)
    tool = payload["tool_name"].to_s
    input = payload["tool_input"].is_a?(Hash) ? payload["tool_input"] : {}
    cwd = payload["cwd"].to_s.empty? ? Dir.pwd : payload["cwd"].to_s
    ctx = { cfgs: config_dirs(env), cwd: cwd }

    case tool
    when "Bash"
      analyze(input["command"].to_s, ctx, 0)
    when "Read", "Edit", "Write", "NotebookEdit", "MultiEdit"
      path_reason(input["file_path"] || input["notebook_path"], ctx, reader: false)
    when "Grep", "Glob"
      [ input["path"], input["pattern"], input["glob"] ].compact.filter_map do |value|
        path_reason(value, ctx, reader: true)
      end.first
    end
  end

  def config_dirs(env)
    home = home_dir
    dirs = [ File.join(home, ".config", "messengerr") ]
    custom = env["MESSENGERR_CONFIG_DIR"].to_s.strip
    dirs << File.expand_path(custom, home) unless custom.empty?
    dirs.uniq
  end

  def home_dir
    Dir.home
  rescue ArgumentError
    "/"
  end

  # ------------------------------------------------------------------ paths

  CRED_MSG = "refusing to touch the messengerr credentials or master key. " \
             "Credentials are managed by the human via `messengerr credentials`.".freeze

  def path_reason(value, ctx, reader:)
    value = value.to_s
    return nil if value.empty?

    word_reason(value, ctx, reader_program: reader)
  end

  # Does this word name (or glob to) something inside the messengerr config dir?
  def word_reason(word, ctx, reader_program: false)
    word = word.sub(/\A\d*[<>]+&?\d*/, "") # redirect prefixes such as 2> or <
    return nil if word.empty?
    return CRED_MSG if word.include?("MESSENGERR_MASTER_KEY")

    candidates = [ word ]
    candidates << word.split("=", 2).last if word.include?("=")
    candidates.uniq.each do |candidate|
      abs = expand(candidate, ctx)
      next if abs.nil?
      return CRED_MSG if inside_config?(abs, ctx[:cfgs])
      return CRED_MSG if glob?(abs) && glob_hits_config?(abs, ctx[:cfgs])
      return CRED_MSG if reader_program && ancestor_of_config?(abs, ctx[:cfgs])
    end
    nil
  end

  def expand(word, ctx)
    text = word.dup
    text = text.sub(/\A~(?=\/|\z)/, home_dir)
    text = text.gsub(/\$\{?HOME\}?/, home_dir)
    text = text.gsub(/\$\{?MESSENGERR_CONFIG_DIR\}?/, ctx[:cfgs].last)
    return nil if text.include?("$") # unknown variable: cannot resolve

    File.expand_path(text, ctx[:cwd])
  rescue ArgumentError
    nil
  end

  def glob?(path)
    path.match?(/[*?\[{]/)
  end

  def inside_config?(abs, cfgs)
    cfgs.any? { |cfg| abs == cfg || abs.start_with?("#{cfg}/") }
  end

  # A token like ~/.config/messeng*/master.* or messengerr/m* (after cd ~/.config).
  def glob_hits_config?(pattern, cfgs)
    flags = File::FNM_PATHNAME | File::FNM_DOTMATCH | File::FNM_EXTGLOB
    cfgs.any? do |cfg|
      targets = [ cfg ] + %w[credentials.yml.enc master.key .credentials.yml.enc.tmp .master.key.tmp].map { |f| File.join(cfg, f) }
      targets.any? { |target| File.fnmatch?(pattern, target, flags) || File.fnmatch?(pattern.chomp("/") + "/**", "#{target}/x", flags) }
    end
  end

  def ancestor_of_config?(abs, cfgs)
    cfgs.any? { |cfg| abs != cfg && cfg.start_with?("#{abs.chomp('/')}/") && abs.end_with?(".config", ".config/") }
  end

  # ------------------------------------------------------------------ shell

  def analyze(cmd, ctx, depth)
    return "command nesting is too deep to inspect; blocked to be safe" if depth > MAX_DEPTH

    cmd = cmd.gsub("\\\n", "")
    commands, nested = lex(cmd)

    nested.each do |inner|
      reason = analyze(inner, ctx, depth + 1)
      return reason if reason
    end

    vars = {}
    local = ctx.merge(cwd: ctx[:cwd])
    commands.each do |raw|
      words = resolve_variables(raw, vars)
      words = strip_assignments(words, vars)
      next if words.empty?

      reason = command_reason(words, commands, local, depth)
      return reason if reason

      if %w[cd pushd].include?(File.basename(words.first)) && words[1]
        target = expand(words[1], local)
        local = local.merge(cwd: target) if target
      end
    end
    nil
  end

  def strip_assignments(words, vars)
    words = words.dup
    while words.first&.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/)
      name, value = words.shift.split("=", 2)
      vars[name] = value unless value.include?("$")
    end
    words
  end

  # $name / ${name} for variables assigned earlier in the same command line.
  def resolve_variables(words, vars)
    words.flat_map do |word|
      if (m = word.match(/\A\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?\z/)) && vars.key?(m[1])
        vars[m[1]].split
      else
        [ word.gsub(/\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/) { vars.fetch(Regexp.last_match(1)) { Regexp.last_match(0) } } ]
      end
    end
  end

  def command_reason(words, all_commands, ctx, depth)
    prog = File.basename(words.first)

    words.each do |word|
      reason = word_reason(word, ctx, reader_program: READERS.include?(prog))
      return reason if reason
    end

    reason = env_dump_reason(prog, words)
    return reason if reason

    reason = messengerr_reason(words)
    return reason if reason

    reason = indirection_reason(words)
    return reason if reason

    reason = interpreter_reason(prog, words, ctx, depth)
    return reason if reason

    piped_text_reason(prog, words, all_commands, ctx, depth)
  end

  def env_dump_reason(prog, words)
    return nil unless ENV_DUMPERS.include?(prog)

    args = words.drop(1)
    dumps =
      case prog
      when "env" then args.reject { |a| a.start_with?("-") || a.include?("=") }.empty?
      when "printenv" then args.empty? || args.any? { |a| a.match?(/MASTER|KEY|MESSENGERR/i) }
      when "export" then args.empty? || args.include?("-p")
      when "set" then args.empty?
      when "declare", "typeset" then args.empty? || args.any? { |a| a.match?(/\A-[a-z]*[px]/) }
      when "compgen" then args.include?("-v") || args.include?("-e")
      end
    dumps ? "refusing to print environment variables: they can include MESSENGERR_MASTER_KEY." : nil
  end

  # The heart of the guard: any word that is the messengerr program.
  def messengerr_reason(words)
    words.each_with_index do |word, index|
      next unless File.basename(word) == "messengerr"

      args = words.drop(index + 1)
      sub = args.find { |arg| !arg.start_with?("-") }
      case sub
      when "send" then reason = send_reason(args)
      when "credentials"
        action = args.drop_while { |arg| arg != "credentials" }.drop(1).find { |arg| !arg.start_with?("-") }
        reason = %w[setup delete].include?(action) ? "`messengerr credentials #{action}` handles secrets: the human runs it, not Claude." : nil
      end
      return reason if reason
    end
    nil
  end

  def send_reason(args)
    if args.include?("--allow-non-interactive")
      return "`--allow-non-interactive` is for the human's own scripts, not for this skill."
    end
    return nil if args.any? { |arg| SAFE_SEND_FLAGS.include?(arg) }

    "refusing `messengerr send` without --dry-run. Claude prepares and dry-runs; the human sends."
  end

  # `$m send`, `mess*r send`: the program is hidden behind a variable or a glob.
  def indirection_reason(words)
    send_at = words.index("send")
    return nil unless send_at

    head = words.first(send_at)
    hidden = head.any? { |w| w.start_with?("$") || w.match?(/\A[^=]*[*?\[]/) && w !~ /\A-/ }
    return nil unless hidden
    return nil if words.any? { |arg| SAFE_SEND_FLAGS.include?(arg) } && words.exclude?("--allow-non-interactive")

    "refusing a command that hides `send` behind a variable or glob; run `messengerr send --dry-run` plainly."
  end

  def interpreter_reason(prog, words, ctx, depth)
    if %w[bash sh zsh dash ksh].include?(prog) || (prog.match?(/\A-?\w+sh\z/) && !SCRIPTING.include?(prog))
      if (c = words.index { |w| w.match?(/\A-[a-z]*c[a-z]*\z/) }) && words[c + 1]
        return analyze(words[c + 1], ctx, depth + 1)
      end
      return script_file_reason(words.drop(1), ctx, depth, shell: true)
    end

    return analyze(words.drop(1).join(" "), ctx, depth + 1) if prog == "eval"
    return script_file_reason(words.drop(1), ctx, depth, shell: true) if %w[source .].include?(prog)

    if SCRIPTING.include?(prog) || prog.match?(/\A(ruby|python)[\d.]*\z/)
      text = words.drop(1).join(" ")
      reason = text_reason(text)
      return reason if reason

      return script_file_reason(words.drop(1), ctx, depth, shell: false)
    end
    nil
  end

  # `echo 'messengerr send' | bash`, `printf ... | sh`
  def piped_text_reason(prog, words, all_commands, ctx, depth)
    return nil if SHELLS.include?(prog) # handled above
    return nil unless all_commands.any? { |c| SHELLS.include?(File.basename(c.first.to_s)) }

    words.each do |word|
      next unless word.match?(/messengerr\s+send/)

      # printf/echo -e turn \n into real newlines before the shell sees the text
      reason = analyze(word.gsub("\\n", "\n"), ctx, depth + 1)
      return reason if reason
    end
    return "refusing to decode text into a shell; run commands plainly." if %w[base64 xxd openssl].include?(prog) &&
                                                                              words.any? { |w| w.match?(/\A-(d|D|r|-decode)\z/) }
    nil
  end

  def script_file_reason(args, ctx, depth, shell:)
    file = args.find { |arg| !arg.start_with?("-") }
    return nil unless file

    path = expand(file, ctx)
    return nil unless path && File.file?(path) && File.size(path) <= MAX_FILE

    body = File.read(path, encoding: "utf-8", invalid: :replace, undef: :replace)
    shell ? analyze(body, ctx, depth + 1) : text_reason(body)
  rescue SystemCallError
    nil
  end

  # Fail-closed text rule for code we cannot parse (ruby -e, python -c, script files).
  def text_reason(text)
    return CRED_MSG if text.include?("MESSENGERR_MASTER_KEY") || text.include?(".config/messengerr")
    return nil unless text.match?(/messengerr/) && text.match?(/\bsend\b/)
    return nil if text.match?(/--dry-run/) && !text.include?("--allow-non-interactive")

    "refusing code that runs `messengerr send` without --dry-run."
  end

  # ------------------------------------------------------------------ lexer

  # → [commands (arrays of words), nested command strings from $( ) and `` inside quotes]
  def lex(cmd)
    commands = []
    nested = []
    current = []
    word = +""
    has_word = false
    in_single = false
    in_double = false
    i = 0
    n = cmd.length

    flush = lambda do
      if has_word
        current << word
        word = +""
        has_word = false
      end
    end
    finish = lambda do
      flush.call
      commands << current unless current.empty?
      current = []
    end

    while i < n
      c = cmd[i]

      if in_single
        c == "'" ? in_single = false : word << c
        i += 1
        next
      end

      if in_double
        case c
        when '"' then in_double = false
        when "\\"
          nxt = cmd[i + 1]
          if nxt && "$`\"\\".include?(nxt)
            word << nxt
            i += 1
          else
            word << c
          end
        when "$"
          if cmd[i + 1] == "("
            body, i = paren_body(cmd, i + 2)
            nested << body
            word << "$(...)"
            next
          end
          word << c
        when "`"
          close = cmd.index("`", i + 1) || (n - 1)
          nested << cmd[(i + 1)...close]
          word << "`...`"
          i = close
        else word << c
        end
        i += 1
        next
      end

      case c
      when "'" then in_single = true
                    has_word = true
      when '"' then in_double = true
                    has_word = true
      when "\\"
        nxt = cmd[i + 1]
        if nxt
          word << nxt
          has_word = true
          i += 1
        end
      when " ", "\t" then flush.call
      when "\n", ";", "&", "|", "(", ")", "`" then finish.call
      when "{", "}"
        before = i.zero? || cmd[i - 1].match?(/\s|;|&|\|/)
        after = cmd[i + 1].nil? || cmd[i + 1].match?(/\s|;|&|\|/)
        if before && after && word.empty?
          finish.call
        else
          word << c
          has_word = true
        end
      when "#"
        if word.empty? && !has_word
          i += 1 while i < n && cmd[i] != "\n"
          next
        end
        word << c
        has_word = true
      when "$"
        if cmd[i + 1] == "{"
          close = cmd.index("}", i + 2) || (n - 1)
          word << cmd[i..close]
          has_word = true
          i = close
        else
          word << c
          has_word = true
        end
      else
        word << c
        has_word = true
      end
      i += 1
    end
    finish.call
    [ commands, nested ]
  end

  # Text inside $( ... ) with nesting; returns [body, index after the closing paren].
  def paren_body(cmd, start)
    depth = 1
    i = start
    while i < cmd.length
      case cmd[i]
      when "(" then depth += 1
      when ")"
        depth -= 1
        return [ cmd[start...i], i + 1 ] if depth.zero?
      end
      i += 1
    end
    [ cmd[start..], cmd.length ]
  end

  # ------------------------------------------------------------------ entry

  def run(stdin: $stdin, stderr: $stderr, env: ENV)
    raw = stdin.read.to_s
    payload = begin
      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    reason =
      if payload.is_a?(Hash)
        check(payload, env: env)
      else
        text_reason(raw) # unreadable payload: only fail closed on the dangerous words
      end

    return 0 unless reason

    stderr.puts "messengerr guard: #{reason}"
    2
  rescue StandardError => e
    # Never crash into "allow" when the payload clearly involves a send.
    if raw.to_s.match?(/messengerr/) && raw.to_s.match?(/\bsend\b/) && !raw.to_s.match?(/--dry-run/)
      stderr.puts "messengerr guard: internal error (#{e.class}); blocked to be safe."
      2
    else
      0
    end
  end
end

exit MessengerrGuard.run if $PROGRAM_NAME == __FILE__
