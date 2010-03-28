module Merb
  module GlobalHelpers
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
        <a href="#{resource(find)}">Back to <strong>#{find.specification.inspect}</strong> results</a>
  			<img src="/images/panel/backgrounds/title_button_sep.png">
  			<hr class="terminator" />
			HTML
    end
        
    def product_data_panel(values)
      html = []
      
      brands = values.map { |info| info[:raw_name] == "marketing:brand" ? info[:values] : [] }.flatten.uniq
      logos = Brand.logos(brands)
      html << "<div class=\"advert\"> <img src=#{logos[rand(logos.size)].url.inspect} /> </div>" unless logos.empty?
      	
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
      
      html << "</div>"
      
      html.join("\n")
    end
    
    def product_image(image)
      url, popup_url = product_image_urls(image)
      "<img class=\"product\" src=#{url.inspect} onmouseover=\"product_image_popup(event, '#{popup_url}')\" onmouseout=\"product_image_unpopup(event)\" />"
    end
    
    def product_image_urls(image)
      image.nil? ? Array.new(2) { "/images/common/no_image.png" } : [image.url(:tiny), image.url(:small)]
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
        
        d = definition.gsub(/(['"])/) { "\\" + $1 }
        values << <<-HTML
    	    <span class="defined" onmouseover="tooltip_show(event, '#{d}', '#{tooltip_position}')" onmouseout="tooltip_hide()">#{value}</span>
    	  HTML
      end
      
      if info[:type] == 'text' then values.map! { |value| value.superscript }
      else values.map! { |value| value.superscript_numeric }
      end
      values.join("<br />")
    end
    
    def property_icon(url, tooltip, position = :right)
      t = tooltip.gsub(/(')/) { "\\'" }
      <<-HTML
        <img class="icon" src=#{url.inspect} onmouseover="tooltip_show(event, '#{t}', '#{position}')" onmouseout="tooltip_hide()" />
      HTML
    end
  end
end
