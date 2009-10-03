module Merb
  module GlobalHelpers
    def defined_value(value, definition)
      return value if definition.nil?
      definition.gsub!(/(['"])/) { '\\' + $1 }
      "<span class=\"defined\" onmouseover=\"bubble_tooltip_show(event, '#{definition}')\" onmouseout=\"bubble_tooltip_hide()\">#{value}</span>"
    end
    
    def product_summary(product_id, values_by_name, image_url)
      <<-EOS
      <a class="product" id="prod_#{product_id}" href="/products/#{product_id}">
      	<img src=#{image_url.inspect} onmouseover="prod_list_image_zoom(event)" onmouseout="prod_list_image_unzoom(this)"/>
      	#{product_titles(product_id, values_by_name)}
      	<p>#{values_by_name["marketing:summary"]}</p>
      	<hr />
      </a>
      EOS
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
			"number_format([#{values.join(', ')}], #{value.unit.nil? ? 'undefined' : value.unit.inspect}, #{value.class.date?})"
    end
    
    def product_titles(product_id, titles)
      lines = []
      
      TitleStrategy::TITLE_PROPERTIES.each do |title|
        tag = (title == :title_4 ? "h2" : "h1")
        tag_id = "prod_#{product_id}_#{title}"
        lines << "<#{tag} id=#{tag_id.inspect}></#{tag}>"
        lines << title_js(tag_id, titles[title])
      end
      
      lines.join("\n")
    end

    def title_js(dom_id, parts)
      js_parts = []
      
      last_part = nil
      parts.each do |part|
        case part
        when "SEP"
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
