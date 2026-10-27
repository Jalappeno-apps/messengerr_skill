require_relative "test_helper"
require "tmpdir"

class LedgerSummaryTest < Minitest::Test
  def test_summarises_counts_and_failures
    out, _err, status = run_script("ledger_summary.rb", File.join(FIXTURES, "ledger.jsonl"))
    assert_equal 0, status.exitstatus
    assert_match(/sent: 1/, out)
    assert_match(/failed: 2/, out)
    assert_match(/uncertain \(retry may duplicate\): 1/, out)
    assert_match(/row 3: invalid recipient/, out)
    assert_match(/row 4: read timeout \[uncertain\]/, out)
  end

  def test_tolerates_torn_last_line
    out, _err, status = run_script("ledger_summary.rb", File.join(FIXTURES, "ledger.jsonl"))
    assert_equal 0, status.exitstatus
    assert_match(/torn\/blank lines skipped: 1/, out)
  end

  def test_never_prints_contacts
    out, _err, _status = run_script("ledger_summary.rb", File.join(FIXTURES, "ledger.jsonl"))
    refute_match(/a@x\.com/, out)
  end

  def test_missing_file
    _out, err, status = run_script("ledger_summary.rb", "/nope.jsonl")
    assert_equal 1, status.exitstatus
    assert_match(/not found/, err)
  end

  def test_masks_addresses_and_numbers_in_provider_reasons
    out, _err, status = run_script("ledger_summary.rb", File.join(FIXTURES, "ledger_pii.jsonl"))

    assert_equal 0, status.exitstatus
    assert_match(/row 6: Found inactive addresses: \[email\]\./, out)
    assert_match(/row 7: Invalid number \[number\] \(and \[number\]\)/, out)
    refute_match(/bob@example\.com/, out)
    refute_match(/2025550123|7946 0958/, out)
  end

  def test_keeps_row_numbers_and_ordinary_text
    out, _err, _status = run_script("ledger_summary.rb", File.join(FIXTURES, "ledger_pii.jsonl"))

    assert_match(/row 6:/, out)
    assert_match(/row 7:/, out)
  end

  def test_tolerates_a_ledger_of_non_objects
    Dir.mktmpdir do |dir|
      path = File.join(dir, "l.jsonl")
      File.write(path, "[1,2]\n\"text\"\n42\n{\"status\":\"sent\",\"row_number\":2}\n")
      out, _err, status = run_script("ledger_summary.rb", path)

      assert_equal 0, status.exitstatus
      assert_match(/sent: 1/, out)
    end
  end
end
