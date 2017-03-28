# frozen_string_literal: true
module TaskVault
  module Operators
    TRANSLATIONS = {
      eq:     'is equal to',
      starts: 'starts with',
      ends:   'ends with',
      gt:     'is greater than',
      gte:    'is greater than or equal to',
      lt:     'is less than',
      lte:    'is less than or equal to',
      within: 'is contained in',
      exists: 'exists',
      empty:  'is empty'
    }.freeze

    INVERTED_TRANSLATIONS = {
      eq:     'is not equal to',
      starts: 'does not starts with',
      ends:   'does not ends with',
      gt:     'is not greater than',
      gte:    'is not greater than or equal to',
      lt:     'is not less than',
      lte:    'is not less than or equal to',
      within: 'is not contained in',
      exists: 'does not exist',
      empty:  'is not empty'
    }.freeze

    def self.eq(val, exp)
      val.to_s == exp.to_s
    end

    def self.contains(val, exp)
      val.include?(exp)
    end

    def self.matches(val, exp)
      val =~ Regexp.new(exp)
    end

    def self.starts(val, exp)
      val.to_s.start_with?(exp)
    end

    def self.ends(val, exp)
      val.to_s.end_with?(exp)
    end

    def self.gt(val, exp)
      val > exp
    end

    def self.gte(val, exp)
      val >= exp
    end

    def self.lt(val, exp)
      val < exp
    end

    def self.lte(val, exp)
      val <= exp
    end

    def self.within(val, exp)
      if exp.is_a?(Array)
        exp.map(&:to_s).include?(val.to_s)
      else
        Range.new(*exp.split('..').map(&:to_f)).include?(val.to_f)
      end
    end

    def self.exists(val, exp)
      val.nil?
    end

    def self.empty(val, exp)
      val.nil? || val.empty? rescue false
    end

    def self.proc(val, exp)
      exp.call(val)
    end
  end
end
