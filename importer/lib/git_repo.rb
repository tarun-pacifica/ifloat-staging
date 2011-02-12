module GitRepo
  def self.summarize(paths_by_name)
    paths_by_name.map do |name, path|
      "#{name}: " + `git --git-dir='#{path}/.git' log -n1 --pretty='format:%H from %ai by %cn'`.chomp
    end
  end
end
