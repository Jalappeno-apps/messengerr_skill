require_relative "test_helper"

class CsvCheckTest < Minitest::Test
  def test_good_csv
    out, _err, status = run_script("csv_check.rb", File.join(FIXTURES, "good.csv"))
    assert_equal 0, status.exitstatus
    assert_match(/headers: name, email, phone/, out)
    assert_match(/duplicate headers: none/, out)
    assert_match(/data rows: 2/, out)
  end

  def test_detects_bom
    out, _err, status = run_script("csv_check.rb", File.join(FIXTURES, "bom.csv"))
    assert_equal 0, status.exitstatus
    assert_match(/bom: utf-8/, out)
    assert_match(/headers: name, email/, out)
  end

  def test_flags_duplicate_headers
    out, _err, status = run_script("csv_check.rb", File.join(FIXTURES, "dupes.csv"))
    assert_equal 0, status.exitstatus
    assert_match(/duplicate headers: email/, out)
  end

  def test_counts_blanks_and_empties
    out, _err, status = run_script("csv_check.rb", File.join(FIXTURES, "blanks.csv"))
    assert_match(/data rows: 3/, out)
    assert_match(/blank rows: 1/, out)
    assert_match(/email: 2 empty/, out)
  end

  def test_missing_file
    _out, err, status = run_script("csv_check.rb", "/nope.csv")
    assert_equal 1, status.exitstatus
    assert_match(/not found/, err)
  end

  def test_never_prints_contact_values
    out, _err, _status = run_script("csv_check.rb", File.join(FIXTURES, "good.csv"))
    refute_match(/alice@example\.com/, out)
    refute_match(/12025550123/, out)
  end
end
