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
      	<%= product_titles(product_id, values_by_name) %>
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
      js_parts = parts.map do |part|
        case part
        when "SEP" then '"&mdash;"'
        when NumericPropertyValue then number_format_js(part)
        else part.to_s.inspect
        end
      end
      
      '<script type="text/javascript" charset="utf-8">' +
      '$("#' + dom_id.to_s + '").html([' + js_parts.join(", ") + '].join(" "));' +
      '</script>'
    end
  end
end
