require_relative "test_helper"

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
end
