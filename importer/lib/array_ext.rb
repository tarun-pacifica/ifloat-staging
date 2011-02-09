class Array
  def delete_and_log(entity_description)
    return if size == 0
    FileUtils.rmtree(self)
    puts " - deleted #{size} #{entity_description}"
  end
end
