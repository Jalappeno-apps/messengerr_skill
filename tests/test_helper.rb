$LOAD_PATH.unshift File.expand_path(__dir__)

require "minitest/autorun"
require "open3"
require "json"
require "shellwords"

ROOT = File.expand_path("..", __dir__)
SCRIPTS = File.join(ROOT, "skills/messengerr/scripts")
FIXTURES = File.join(__dir__, "fixtures")

# Run a script, optionally with stdin. → [stdout, stderr, status]
def run_script(script, *args, stdin: "", env: {})
  cmd = [File.join(SCRIPTS, script), *args]
  env = env.merge("PATH" => "#{ENV['MESSENGERR_STUB_BIN']}:#{ENV['PATH']}") if ENV["MESSENGERR_STUB_BIN"]
  out, err, status = Open3.capture3(env, *cmd, stdin_data: stdin)
  [out, err, status]
end

# Feed hook JSON to guard_send.sh as Claude Code would.
def run_guard(command)
  payload = JSON.dump("tool_input" => { "command" => command })
  run_script("guard_send.sh", stdin: payload)
end
