require "spec_helper"

describe Lhm::Adapter, "#add_column" do
  it_behaves_like "column-definition method", :add_column
end
