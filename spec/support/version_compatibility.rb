
module VersionCompatibility
  def self.compatible?(version_string, compatibility_string)
    raise "Invalid Gem Version: '#{version_string}'" unless Gem::Version.correct?(version_string)

    comparator, target = compatibility_string.match(/(\D*?)\s*(\d+.*)/).captures
    raise "Incorrect Gem Version for target: '#{target}'" unless Gem::Version.correct? target
    case comparator
    when "<"  then version_string < target
    when "<=" then version_string <= target
    when ">"  then version_string > target
    when ">=" then version_string >= target
    else
      raise "Unsupported Compatability string: '#{activerecord_compatibility}', don't know how to compare using '#{comparator}'"
    end
  end
end
