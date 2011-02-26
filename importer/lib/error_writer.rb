module ErrorWriter
  def write_errors(to_path)
    return false if @errors.empty?
    
    FasterCSV.open(to_path, "w") do |csv|
      csv << self.class.const_get("ERROR_HEADERS")
      @errors.each { |fields| csv << fields }
    end
    true
  end
end
