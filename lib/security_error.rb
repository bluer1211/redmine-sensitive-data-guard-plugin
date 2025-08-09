# frozen_string_literal: true

# 安全錯誤類別
class SecurityError < StandardError
  attr_reader :risk_level, :details

  def initialize(message, risk_level = 'unknown', details = {})
    super(message)
    @risk_level = risk_level
    @details = details
  end
end
