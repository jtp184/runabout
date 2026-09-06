class ClassificationRule < ApplicationRecord
  def self.classify(categories)
    order(priority: :desc).each do |rule|
      return rule.display_type if categories.any? { |category| Regexp.new(rule.pattern, Regexp::IGNORECASE).match?(category) }
    end
    "Other"
  end
end
