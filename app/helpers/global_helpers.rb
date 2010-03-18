module Merb
  module GlobalHelpers    
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
    
    def product_data_panel(properties)
      html = []
      
      properties.group_by { |info| info[:section] }.each do |section, infos|
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
  end
end
