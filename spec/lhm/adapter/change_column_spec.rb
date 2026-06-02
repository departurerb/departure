require "spec_helper"

describe Lhm::Adapter, "#change_column" do
  it_behaves_like "column-definition method", :change_column
end
