class AutoObjectGenerator
  include ErrorWriter
  
  ERROR_HEADERS = %w(csv row error)
  VALUE_CLASSES = PropertyValue.descendants.map { |d| [d] + d.descendants.to_a }.flatten.to_set
  
  def initialize(csv_catalogue, object_catalogue)
    @csvs = csv_catalogue
    @objects = object_catalogue
    
    @errors = []
    @strategies_by_class_args = {}
    
    @agd_property, @at_property = %w(auto:group_diff auto:title).map do |name|
      ref = ObjectRef.for(PropertyDefinition, [name])
      @errors << "#{name} property not found - cannot generate values without it" unless @objects.has_ref?(ref)
      ref
    end
  end
  
  def error_no_strategy(type, for_class, row_md5)
    type = {:ph => "property hierarchy", :ts => "title strategy"}[type]
    error_for_row("no #{type} for reference:class #{for_class.inspect}", row_md5)
  end
  
  def generate
    return unless @errors.empty?
    
    products_done = 0
    products_todo = @objects.queue_size("refs_by_product", true)
    
    @objects.queue_each("refs_by_product") do |product_ref, refs|
      product = @objects.data_for(product_ref)
      products_done += 1
      
      if product.nil?
        refs
      else
        values = refs.map(&@objects.method(:data_for)).compact
        values_by_property_name = values.group_by { |v| v[:definition][:name] }
        
        klass = values_by_property_name["reference:class"].first[:text_value]
        row_md5 = @objects.row_md5s_for(product_ref).first
        args = [product_ref, product, klass, values_by_property_name, row_md5]
        
        methods = [method(:generate_ts_values)]
        methods << method(:generate_ph_values) unless product[:reference_group].nil?
        
        auto_objects, errors = [], []
        methods.each do |m|
          aos, es = m.call(*args)
          auto_objects += aos
          errors += es
        end
        errors += @objects.add(auto_objects, row_md5).map { |e| error_for_row(e, row_md5) }
        @errors += errors
        
        puts " - processed #{products_done}/#{products_todo} new/updated products" if products_done % 500 == 0
        errors.empty? ? refs : []
      end
    end
    puts " - processed #{products_done}/#{products_todo} new/updated products" if products_todo % 500 > 0
    
    puts " ! #{@errors.size} errors reported" unless @errors.empty?
    @objects.flush
  end
  
  def generate_auto_part(values, capitalize, superscript_units)
    klass = values.first[:class]
    values = values.sort_by { |v| v[:sequence_number] }
    
    if klass == TextPropertyValue
      part = values.map { |v| v[:text_value] }.join(", ")
      capitalize ? part.gsub!(/(^|\s)\S/) { $&.upcase } : part
    else
      min_seq_num = values.first[:sequence_number]
      values = values.select { |v| v[:sequence_number] == min_seq_num }
      values = values.sort_by { |v| v[:unit].to_s }
      formatted_values = values.map do |v|
        value = klass.format(v[:min_value], v[:max_value], "-", v[:unit])
        superscript_units ? value.superscript_numeric : value
      end
      formatted_values.join(" / ")
    end
  end
  
  def generate_ph_values(product_ref, product, klass, values_by_property_name, row_md5)
    diff_objects = []
    
    seq_num = 0
    while seq_num += 1 do
      hierarchy, hierarchy_ref = strategy_for(PropertyHierarchy, [klass, seq_num])
      if hierarchy.nil?
        return [[], [error_no_strategy(:ph, klass, row_md5)]] if seq_num == 1
        break
      end
      
      rendered_parts = []
      hierarchy[:property_names].map do |name|
        values = values_by_property_name[name]
        rendered_parts << generate_auto_part(values, false, false) unless values.nil?
      end
      
      diff_objects << {
        :class => TextPropertyValue,
        :definition => @agd_property,
        :product => product_ref,
        :auto_generated => true,
        :sequence_number => seq_num,
        :language_code => "ENG",
        :text_value => rendered_parts.join(" - "),
        :property_hierarchy => hierarchy_ref # ensures dependency chain for deletions / updates
      }
    end
    
    [diff_objects, []]
  end
  
  def generate_ts_values(product_ref, product, klass, values_by_property_name, row_md5)
    title_objects, errors = [], []
    
    strategy, strategy_ref = strategy_for(TitleStrategy, [klass])
    return [[], [error_no_strategy(:ts, klass, row_md5)]] if strategy.nil?
    
    TitleStrategy::TITLE_PROPERTIES.each_with_index.map do |title, i|
      rendered_parts = []
      strategy[title].each do |part|
        if part == "-"
          rendered_parts << "-" unless rendered_parts.empty? or rendered_parts.last == "-"
        elsif part == "product.reference"
          rendered_parts << product[:reference]
        else
          values = values_by_property_name[part]
          notDescription = (title != :description)
          rendered_parts << generate_auto_part(values, notDescription, notDescription) unless values.nil?
        end
      end
      rendered_parts.pop while rendered_parts.last == "-"
      
      if rendered_parts.empty? then errors << error_for_row("empty #{title} title", row_md5)
      else title_objects << {
          :class => TextPropertyValue,
          :definition => @at_property,
          :product => product_ref,
          :auto_generated => true,
          :sequence_number => i + 1,
          :language_code => "ENG",
          :text_value => rendered_parts.join(" "),
          :title_strategy => strategy_ref # ensures dependency chain for deletions / updates
        }
      end
    end
    
    errors.empty? ? [title_objects, []] : [[], errors]
  end
  
  def strategy_for(klass, args)
    key = [klass, args]
    return @strategies_by_class_args[key] if @strategies_by_class_args.has_key?(key)
    strategy_ref = ObjectRef.for(klass, args)
    strategy = strategy_ref.attributes unless strategy_ref.nil?
    @strategies_by_class_args[key] = [strategy, strategy_ref]
  end
end
