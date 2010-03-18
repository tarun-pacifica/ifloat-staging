module Merb
  module GlobalHelpers
    # TODO: remove as/when uneeded by product view
    def defined_value(value, definition)
      return value if definition.nil?
      definition.gsub!(/(['"])/) { '\\' + $1 }
      "<span class=\"defined\" onmouseover=\"tooltip_show(event, '#{definition}', 'right')\" onmouseout=\"tooltip_hide()\">#{value}</span>"
    end
    
    def money(amount, currency = session.currency)
      return nil if amount.nil?
      
      prefix =
        case currency
        when "GBP" then "&#163;"
        else nil
        end
        
      postfix = (prefix.nil? ? " #{currency}" : nil)
      
      [prefix, "%0.2f" % amount, postfix].join
    end
    
    def number_format_js(value)
      v = value.value
      values = (value.range? ? [v.first, v.last] : [v])
			"util_format_number([#{values.join(', ')}], #{value.unit.nil? ? 'undefined' : value.unit.inspect}, #{value.class.date?})"
    end
    
    def product_data_panel(properties)
      html = []
      
      properties.group_by { |info| info[:section] }.each do |section, infos|
        p section
        # p infos
        
        html << "<h3>#{section}</h3>"

        infos.each do |info|
          html << <<-HTML
            <table class="property">
              <tr>
                <td class="icon"> #{property_icon(info[:icon_url], info[:name])} </td>
                <td class="summary"> #{product_value_summary(info)} </td>
              </tr>
            </table>
          HTML
        end
        
        html << '<hr class="terminator" />'
      end
      
      html.join("\n")
    end
    
    def product_image(image)
      url, popup_url = product_image_urls(image)
      "<img class=\"product\" src=#{url.inspect} onmouseover=\"product_image_popup(event, '#{popup_url}')\" onmouseout=\"product_image_unpopup()\" />"
    end
    
    def product_image_urls(image)
      image.nil? ? Array.new(2) { "/images/products/no_image.png" } : [image.url(:tiny), image.url(:small)]
    end
    
    def product_summary(product_id, values_by_name, image)
      <<-EOS
      <a class="product" id="prod_#{product_id}" href="/products/#{product_id}">
      	#{product_image(image)}
      	#{product_titles(values_by_name["auto:title"])}
      	<p>#{(values_by_name["marketing:summary"] || []).first}</p>
      	<hr />
      </a>
      EOS
    end
    
    def product_value_summary(info, tooltip_position = :right)
      return nil if info.nil?
      
      definitions = (info[:definitions] || [])
      
      values = []
      info[:values].each_with_index do |value, i|
        definition = definitions[i]
        
        if definition.nil?
          values << value
          next
        end
        
        definition.gsub!(/(['"])/) { "\\" + $1 }
        values << <<-HTML
    	    <span class="defined" onmouseover="tooltip_show(event, '#{definition}', '#{tooltip_position}')" onmouseout="tooltip_hide()">#{value}</span>
    	  HTML
      end
      
      values.join("<br />")
    end
    
    def property_icon(url, tooltip, position = :right)
      tooltip.gsub!(/(')/) { "\\'" }
      <<-HTML
        <img class="icon" src=#{url.inspect} onmouseover="tooltip_show(event, '#{tooltip}', '#{position}')" onmouseout="tooltip_hide()" />
      HTML
    end
    
    def product_titles(titles)
      lines = []
      (titles || []).each_with_index do |title, i|
        tag = (i == 4 ? "h2" : "h1")
        lines << "<#{tag}>#{title}</#{tag}>"
      end
      lines.join("\n")
    end
    
    def title_js(dom_id, parts)
      js_parts = []
      
      last_part = nil
      parts.each do |part|
        case part
        when "-"
          js_parts << '" &mdash; "'
        when NumericPropertyValue
          different_property = (last_part.nil? or
            not last_part.is_a?(NumericPropertyValue) or
            last_part.property_definition_id != part.property_definition_id)
          different_sequence = (different_property or last_part.sequence_number != part.sequence_number)
          js_parts << (different_property ? '" "' : (different_sequence ? '", "' : '"_"'))
          js_parts << number_format_js(part)
        else
          js_parts << " #{part} ".inspect
        end
        last_part = part
      end
      
      '<script type="text/javascript" charset="utf-8">' +
      '$("#' + dom_id.to_s + '").html([' + js_parts.join(", ") + '].join(""));' +
      '</script>'
    end
  end
end
