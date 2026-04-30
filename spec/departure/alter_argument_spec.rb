require "spec_helper"

describe Departure::AlterArgument do
  describe "#initialize" do
    it "raises an InvalidAlterStatement if the statement is invalid" do
      statement = "CREATE TABLE `things`"
      expect { described_class.new(statement) }.to(
        raise_error(Departure::InvalidAlterStatement)
      )
    end
  end

  describe "#to_s" do
    it "outputs the --alter argument when there is an ALTER TABLE present" do
      statement = "ALTER TABLE `comments` CHANGE `some_id` `some_id` INT(11) DEFAULT NULL"
      subject = described_class.new(statement)
      expect(subject.to_s).to eq('--alter "CHANGE \`some_id\` \`some_id\` INT(11) DEFAULT NULL"')
    end

    it "escapes double quotes in the --alter argument" do
      statement = 'ALTER TABLE `comments` CHANGE `some_id` `some_id` INT(11) DEFAULT NULL COMMENT \'a"quote\''
      subject = described_class.new(statement)
      expect(subject.to_s).to eq('--alter "CHANGE \`some_id\` \`some_id\` INT(11) DEFAULT NULL COMMENT \'a\\"quote\'"')
    end

    it 'removes "\n" character groups which otherwise would transform into line feeds and terminate the shell input' do
      statement = 'ALTER TABLE `comments`\n CHANGE\n `some_id` `some_id`\n INT(11) DEFAULT NULL'
      subject = described_class.new(statement)
      expect(subject.to_s).to eq('--alter "CHANGE \`some_id\` \`some_id\` INT(11) DEFAULT NULL"')
    end
  end

  describe "#table_name" do
    it "returns the name of the altered table, even if the table name includes grave marks" do
      statement = "ALTER TABLE `comments` CHANGE `some_id` `some_id` INT(11) DEFAULT NULL"
      alter_argument = described_class.new(statement)
      expect(alter_argument.table_name).to eq("comments")
    end

    it "returns the name of the altered table, if the table name does not include grave marks" do
      statement = "ALTER TABLE comments CHANGE `some_id` `some_id` INT(11) DEFAULT NULL"
      alter_argument = described_class.new(statement)
      expect(alter_argument.table_name).to eq("comments")
    end
  end
end
