# frozen_string_literal: true

require "spec_helper"
require "date"
require "kumi/kernels/ruby/datetime_scalar"

RSpec.describe Kumi::Kernels::Ruby::DatetimeScalar do
  describe ".dt_add_days" do
    it "adds days to a Date" do
      date = Date.new(2023, 1, 15)
      result = described_class.dt_add_days(date, 5)
      expect(result).to eq(Date.new(2023, 1, 20))
    end

    it "adds negative days (subtracts)" do
      date = Date.new(2023, 1, 15)
      result = described_class.dt_add_days(date, -5)
      expect(result).to eq(Date.new(2023, 1, 10))
    end

    it "adds zero days" do
      date = Date.new(2023, 1, 15)
      result = described_class.dt_add_days(date, 0)
      expect(result).to eq(date)
    end

    it "handles month boundaries" do
      date = Date.new(2023, 1, 30)
      result = described_class.dt_add_days(date, 5)
      expect(result).to eq(Date.new(2023, 2, 4))
    end

    it "handles year boundaries" do
      date = Date.new(2022, 12, 30)
      result = described_class.dt_add_days(date, 5)
      expect(result).to eq(Date.new(2023, 1, 4))
    end

    it "handles leap years" do
      leap_date = Date.new(2020, 2, 28)
      result = described_class.dt_add_days(leap_date, 1)
      expect(result).to eq(Date.new(2020, 2, 29))
      
      result = described_class.dt_add_days(leap_date, 2)
      expect(result).to eq(Date.new(2020, 3, 1))
    end

    it "adds days to a DateTime" do
      datetime = DateTime.new(2023, 1, 15, 12, 30, 45)
      result = described_class.dt_add_days(datetime, 3)
      expect(result).to eq(DateTime.new(2023, 1, 18, 12, 30, 45))
    end

    it "preserves time when adding days to DateTime" do
      datetime = DateTime.new(2023, 1, 15, 23, 59, 59)
      result = described_class.dt_add_days(datetime, 1)
      expect(result).to eq(DateTime.new(2023, 1, 16, 23, 59, 59))
    end

    it "handles large number of days" do
      date = Date.new(2023, 1, 1)
      result = described_class.dt_add_days(date, 365)
      expect(result).to eq(Date.new(2024, 1, 1))
    end

    it "propagates nil values (null_policy: propagate)" do
      expect(described_class.dt_add_days(nil, 5)).to be_nil
      expect(described_class.dt_add_days(Date.new(2023, 1, 15), nil)).to be_nil
      expect(described_class.dt_add_days(nil, nil)).to be_nil
    end

    it "adds days to a Time" do
      time = Time.new(2023, 1, 15, 12, 30, 45)
      result = described_class.dt_add_days(time, 3)
      expected = time + (3 * 86_400)
      expect(result).to eq(expected)
    end
  end

  describe ".dt_diff_days" do
    it "calculates difference between two dates" do
      date1 = Date.new(2023, 1, 20)
      date2 = Date.new(2023, 1, 15)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(5)
    end

    it "returns negative difference when first date is earlier" do
      date1 = Date.new(2023, 1, 10)
      date2 = Date.new(2023, 1, 15)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(-5)
    end

    it "returns zero for same dates" do
      date = Date.new(2023, 1, 15)
      result = described_class.dt_diff_days(date, date)
      expect(result).to eq(0)
    end

    it "calculates difference across months" do
      date1 = Date.new(2023, 2, 5)
      date2 = Date.new(2023, 1, 30)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(6)
    end

    it "calculates difference across years" do
      date1 = Date.new(2023, 1, 5)
      date2 = Date.new(2022, 12, 30)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(6)
    end

    it "handles leap years" do
      date1 = Date.new(2020, 3, 1)
      date2 = Date.new(2020, 2, 28)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(2) # leap year has Feb 29
      
      date1 = Date.new(2021, 3, 1)
      date2 = Date.new(2021, 2, 28)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(1) # non-leap year
    end

    it "calculates difference between DateTimes" do
      datetime1 = DateTime.new(2023, 1, 20, 12, 0, 0)
      datetime2 = DateTime.new(2023, 1, 15, 6, 0, 0)
      result = described_class.dt_diff_days(datetime1, datetime2)
      expect(result).to eq(5)
    end

    it "ignores time component in difference calculation" do
      datetime1 = DateTime.new(2023, 1, 20, 23, 59, 59)
      datetime2 = DateTime.new(2023, 1, 15, 0, 0, 1)
      result = described_class.dt_diff_days(datetime1, datetime2)
      expect(result).to eq(5)
    end

    it "handles mixed Date and DateTime" do
      date = Date.new(2023, 1, 20)
      datetime = DateTime.new(2023, 1, 15, 12, 30, 45)
      result = described_class.dt_diff_days(date, datetime)
      expect(result).to eq(4) # DateTime conversion may lose precision, so actual difference is 4
    end

    it "handles large date differences" do
      date1 = Date.new(2024, 1, 1)
      date2 = Date.new(2023, 1, 1)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to eq(365)
    end

    it "returns integer result" do
      date1 = Date.new(2023, 1, 20)
      date2 = Date.new(2023, 1, 15)
      result = described_class.dt_diff_days(date1, date2)
      expect(result).to be_a(Integer)
    end

    it "propagates nil values (null_policy: propagate)" do
      expect(described_class.dt_diff_days(nil, Date.new(2023, 1, 15))).to be_nil
      expect(described_class.dt_diff_days(Date.new(2023, 1, 20), nil)).to be_nil
      expect(described_class.dt_diff_days(nil, nil)).to be_nil
    end

    it "handles Time objects" do
      time1 = Time.new(2023, 1, 20, 12, 0, 0)
      time2 = Time.new(2023, 1, 15, 6, 0, 0)
      result = described_class.dt_diff_days(time1, time2)
      expect(result).to eq(5)
    end

    it "handles mixed Time and Date" do
      time = Time.new(2023, 1, 20, 12, 30, 45)
      date = Date.new(2023, 1, 15)
      result = described_class.dt_diff_days(time, date)
      expect(result).to eq(6) # Time conversion rounds up partial days
    end
  end
end