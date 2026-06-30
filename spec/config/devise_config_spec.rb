require 'rails_helper'

# Guards security-relevant Devise configuration against regressions.
RSpec.describe "Devise configuration" do # rubocop:disable RSpec/DescribeClass
  it "enables paranoid mode to prevent account enumeration" do
    expect(Devise.paranoid).to be(true)
  end

  it "requires a minimum password length of 8" do
    expect(Devise.password_length.min).to be >= 8
  end
end
