class VersionCompatibility
  def self.matches?(version_string, compatibility_string)
    raise "Invalid Gem Version: '#{version_string}'" unless Gem::Version.correct?(version_string)

    requirement = Gem::Requirement.new(compatibility_string)
    requirement.satisfied_by?(Gem::Version.new(version_string))
  end
end
