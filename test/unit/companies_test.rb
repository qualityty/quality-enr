require 'test_helper'

class CompaniesTest < ActiveSupport::TestCase
  def test_should_be_valid
    assert Companies.new.valid?
  end
end
