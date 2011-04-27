module Partners
  module MarineStore
    def self.compile_references(from_xml_path)
      references = []
      options_by_product_code(from_xml_path).each do |product_code, options|
        traverse_or_report(product_code, options.to_a) do |product_code, reference, notes|
          references << reference
        end
      end
      references
    end
    
    def self.dump_report(from_xml_file_handle, to_csv_path, includer, guesser)
      lines_written = 0
      
      FasterCSV.open(to_csv_path, "w") do |csv|
        csv << ["guesses", "reference", "notes"]
        options_by_product_code(from_xml_file_handle).each do |product_code, options|
          traverse_or_report(product_code, options.to_a) do |product_code, reference, notes|
            next unless includer.call(reference)
            csv << [guesser.call(product_code), reference, notes]
            lines_written += 1
          end
        end
      end
      
      lines_written
    end
    
    def self.options_by_product_code(from_xml_file_handle)
      options_by_product_code = {}
      
      Nokogiri::XML::DocumentFragment.parse(from_xml_file_handle.read).children.each do |node|
        next unless node.name == "ProductAttributeOption_Add"
        product_code, option_code = node.attributes.values_at("product_code", "attribute_code").map { |a| a.text }
        value = node.css("Code").text
        prompt = node.css("Prompt").text
        
        options = (options_by_product_code[product_code] ||= {})
        prompts_by_value = (options[option_code] ||= {})
        prompts_by_value[value] = prompt
      end
      
      options_by_product_code
    end
    
    
    private
    
    def self.traverse_or_report(product_code, options, option_stack = [], prompt_stack = [], &reporter)
      if options.empty?
        ref = "#{product_code};#{option_stack.join(';')}"
        reporter.call(product_code, ref, prompt_stack.join(", "))
        return
      end
      
      option_code, prompts_by_value = options[0]
      prompts_by_value.each do |value, prompt|
        traverse_or_report(product_code, options.drop(1), option_stack + ["#{option_code}=#{value}"], prompt_stack + [prompt], &reporter)
      end
    end
  end
end
