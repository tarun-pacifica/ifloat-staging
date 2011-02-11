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
    
    def self.dump_report(from_xml_path, to_csv_path = "/tmp/ms_variant_refs.csv", &includer)
      classes_by_ms_ref = {}
      classes_by_product_id = TextPropertyValue.all("definition.name" => "reference:class").hash_by(:product_id)
      ProductMapping.all("company.reference" => "GBR-02934378").each do |mapping|
        (classes_by_ms_ref[mapping.reference_parts.first.upcase] ||= []) << classes_by_product_id[mapping.product_id].to_s
      end
      
      lines_written = 0
      FasterCSV.open(to_csv_path, "w") do |csv|
        csv << ["classes", "reference", "notes"]
        options_by_product_code(from_xml_path).each do |product_code, options|
          traverse_or_report(product_code, options.to_a) do |product_code, reference, notes|
            next unless includer.nil? or includer.call(reference)
            classes = (classes_by_ms_ref[product_code.upcase] || []).uniq.sort.join(", ")
            csv << [classes, reference, notes]
            lines_written += 1
          end
        end
      end
      
      lines_written
    end
    
    def self.options_by_product_code(from_xml_path)
      options_by_product_code = {}
      
      Nokogiri::XML::DocumentFragment.parse(File.open(from_xml_path).read).children.each do |node|
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
