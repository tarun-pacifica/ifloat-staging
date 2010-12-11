module Merb
  module GlobalHelpers
    # TODO: refactor to use tooltip_attributes
    def category_link(path_names)
      url = "/categories/" + path_names.join("/")
      url.tr!(" ", "+")
      category = path_names.last
      definition = Indexer.category_definition(category)
      on_hover = (definition.nil? ? nil : "onmouseover=\"tooltip_show(event, '#{definition.attribute_escape(true)}')\"")
      "<a href=#{url.inspect} #{on_hover} onmouseout=\"tooltip_hide()\">#{category}</a>"
    end
    
    def compile_tags
      return @compiled_tags unless @compiled_tags.nil? or @compiled_tags_md5 != Indexer.last_loaded_md5
      
      frequencies_by_tag = Indexer.tag_frequencies(session.language)
      min, max = frequencies_by_tag.values.minmax
      return if min.nil?
      
      normalised_max = (max - min) / 4.0
      @compiled_tags_md5 = Indexer.last_loaded_md5
      @compiled_tags = frequencies_by_tag.sort.map do |tag, frequency|
        [tag, ((frequency - min) / normalised_max).round]
      end
    end
    
    # TODO: refactor to use tooltip_attributes
    def finder_link(spec, klass = "", tag = false, tooltip = nil, tooltip_position = :right)
      finder_spec = (tag ? "{#{spec}}" : spec).attribute_escape(true)
      on_hover = (tooltip.nil? ? nil : "onmouseover=\"tooltip_show(event, '#{tooltip.attribute_escape(true)}', '#{tooltip_position}')\"")
      "<span class=#{klass.inspect} onclick=\"finder_do('#{finder_spec}')\" #{on_hover} onmouseout=\"tooltip_hide()\">#{spec.gsub(/\s+/, "&nbsp;")}</span>"
    end
    
    def friendly_list(items, andor)
      return fallback if items.empty?
      return items.first if items.size == 1
      items[0..-2].join(", ") + " #{andor} #{items.last}"
    end
    
    def hidden_field(*args)
      "<div>#{super}</div>"
    end
    
    def marshal_images(product_ids, limit = nil)
      product_ids_by_checksum = Indexer.image_checksums_for_product_ids(product_ids)
      total = product_ids_by_checksum.values.map { |pids| pids.size }.inject(0, :+)
      
      checksums = product_ids_by_checksum.keys[0, limit || product_ids_by_checksum.size]
      assets_by_checksum = Asset.all(:checksum => checksums).hash_by(:checksum)
      totals_by_checksum = Hash[checksums.map { |c| [c, product_ids_by_checksum[c].size] }]
      
      titles_by_checksum = {}
      product_ids_by_checksum.each do |checksum, product_ids|
        titles_by_checksum[checksum] = [:image, :summary].map { |domain| Indexer.product_title(domain, product_ids.first) }.compact # TODO: remove nil handling once summaries are guaranteed
      end
      
      checksums.map do |checksum|
        asset = assets_by_checksum[checksum]
        [checksum, totals_by_checksum[checksum], asset.url(:tiny), asset.url(:small), titles_by_checksum[checksum]]
      end.unshift(total)
    end
    
    def money(amount, currency, per_unit = nil)
      return nil if amount.nil?
      
      prefix =
        case currency
        when "GBP" then "&#163;"
        else nil
        end
        
      postfix = (prefix.nil? ? " #{currency}" : "")
      postfix += "&nbsp;/&nbsp;#{per_unit.superscript(/(\d)/)}" unless per_unit.nil?
      
      [prefix, "%0.2f" % amount, postfix].join
    end
    
    def money_uom(amount, currency, unit, divisor)
      return money(amount, currency, unit) if divisor.nil?
        
      parts = [money(amount, currency)]
      parts << "(" + money(amount / divisor, currency, unit) + ")" unless divisor == 0
      parts.join("<br/>")
    end
    
    def panel_title_back_to_find(find)
      return "&nbsp;" if find.nil?
      <<-HTML
        <a href="#{resource(find)}">« back to your <strong>#{find.specification.inspect}</strong> results</a>
      HTML
    end
    
    def product_data_panel(values)
      html = []
      
      brands = values.map { |info| info[:raw_name] == "marketing:brand" ? info[:values] : [] }.flatten.uniq
      logos = Brand.logos(brands)
      html << "<div class=\"advert\"> <img src=#{logos[rand(logos.size)].url.inspect} alt=\"brand logo\" /> </div>" unless logos.empty?
      
      html << '<div class="sections">'
      
      seq_nums_by_section = {}
      values_by_section = {}
      values.sort_by { |info| info[:seq_num] }.each do |info|
        next unless info[:dad]
        section = info[:section]
        seq_nums_by_section[section] ||= info[:seq_num]
        (values_by_section[section] ||= []).push(info)
      end
      
      seq_nums_by_section.keys.sort_by { |section| seq_nums_by_section[section] }.each_with_index do |section, i|
        html << ((i == 0 and logos.empty?) ? "<h3 class=\"topmost\">#{section}</h3>" : "<h3>#{section}</h3>")
        
        values_by_section[section].each do |info|
          html << <<-HTML
            <table class="property" summary="property">
              <tr>
                <td class="icon"> #{property_icon(info)} </td>
                <td class="summary"> #{product_value_summary(info)} </td>
              </tr>
            </table>
          HTML
        end
        
        html << '<hr class="terminator" />'
      end
      
      html << "</div>"
      
      html.join("\n")
    end
    
    def product_image(image)
      url, popup_url = product_image_urls(image)
      "<img class=\"product\" src=#{url.inspect} onmouseover=\"product_image_popup(event, '#{popup_url}')\" onmouseout=\"product_image_unpopup(event)\" alt=\"product\" />"
    end
    
    def product_image_urls(image)
      image.nil? ? Array.new(2) { "/images/common/no_image.png" } : [image.url(:tiny), image.url(:small)]
    end
    
    def product_value_summary(info, tooltip_position = :right)
      return nil if info.nil?
      
      values = info[:values].dup
      if info[:type] == 'text' then values.map! { |value| value.superscript }
      else values.map! { |value| value.superscript_numeric }
      end
      
      case info[:raw_name]
      when "marketing:description"
        values.map! do |value|
          value.split("\n").map { |paragraph| "<p>#{paragraph}</p>" }.join
        end
      when "marketing:feature_list"
        return tooltip_list('Features', values, tooltip_position)
      end
      
      (info[:definitions] || []).each_with_index do |definition, i|
        values[i] = tooltip(values[i], definition.superscript, tooltip_position) unless definition.nil?
      end
      
      values.join("<br />")
    end
    
    # TODO: refactor to use tooltip_attributes
    def property_icon(info, position = :right)
      prop_id, src = info.values_at(:id, :icon_url)
      tooltip = info[:name].attribute_escape(true)
      
      if info[:raw_name] == "reference:class"
        <<-HTML
          <img class="property_icon disabled" src="#{src}" alt="#{info[:name]}" onmouseover="tooltip_show(event, '#{tooltip}', '#{position}')" onmouseout="tooltip_hide()" />
        HTML
      else
        <<-HTML
          <img class="property_icon" src="#{src}" alt="#{info[:name]}" onclick="filter_configure(#{prop_id})" onmouseover="tooltip_show(event, '#{tooltip}', '#{position}')" onmouseout="tooltip_hide()" />
        HTML
      end
    end
    
    # TODO: refactor to use tooltip_attributes or even replace all uses with a direct call to that method
    def tooltip(value, tip, position = :right)
      <<-HTML
        <span class="defined" onmouseover="tooltip_show(event, '#{tip.attribute_escape(true)}', '#{position}')" onmouseout="tooltip_hide()">#{value}</span>
      HTML
    end
    
    def tooltip_attributes(tip, position = :right)
      on_hover = (tip.nil? ? nil : "onmouseover=\"tooltip_show(event, '#{tip.attribute_escape(true)}', '#{position}')\"")
      "#{on_hover} onmouseout=\"tooltip_hide()\""
    end
    
    # TODO: refactor to use tooltip_attributes or even replace all uses with a direct call to that method
    def tooltip_list(name, values, position = :right)
      items = values.map { |value| value.split("\n") }.flatten.map { |value| "<li>#{value}</li>" }
      tooltip(name, "<ul>#{items.join}</ul>", position)
    end
  end
end
