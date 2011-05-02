# coding: utf-8

module Merb
  module GlobalHelpers
    def brand_image(brand)
      brand.nil? ? nil : "<img src=\"#{brand.asset.url}\" alt=\"brand logo\" />"
    end
    
    def brand_title(brand, title)
      image = brand_image(brand)
      image.nil? ? title.superscript : "#{image} <span>#{title.superscript}</span>"
    end
    
    def breadcrumbs(category_path_names, filter_prompt = true)
      crumbs = []
      
      find_phrase = params["find"]
      crumbs << category_link([], "\"#{find_phrase}\"") unless find_phrase.nil?
      
      crumbs += category_path_names.size.times.map { |i| category_link(category_path_names[0, i + 1]) }
      
      filters = (JSON.parse(params["filters"]) rescue [])
      filters.each_with_index do |filter, i|
        property_id, unit, value, label = filter
        label = (label.nil? ? value : label.gsub(Application::RANGE_SEPARATOR, "-"))
        crumbs << category_link(category_path_names, label, filters[0, i + 1])
      end
      
      crumbs << '<a class="filter" href="#" onclick="category_filters_show(); return false">Filter your results</a>' if filter_prompt and category_path_names.size == 2
      
      '<div id="breadcrumbs">' + crumbs.join(' <span class="chevron"></span> ') + '</div> <hr class="terminator" />'
    end
    
    def category_link(path_names, name = nil, filters = [])
      url = category_url(path_names)
      
      query_params = []
      
      find_phrase = params["find"]
      query_params << "find=#{find_phrase}" unless find_phrase.nil?
      query_params << "filters=#{URI.encode(filters.to_json)}" unless filters.empty?
      
      url += "?#{query_params.join('&')}" unless query_params.empty?
      image_url = Indexer.category_image_url_for_node(path_names)
      name ||= path_names.last
      <<-HTML
        <a href=#{url.inspect}>
        <img src="#{image_url}" alt="#{name.attribute_escape}" />
        <span>#{Merb::Parse.escape_xml(name)}</span>
        </a>
      HTML
    end
    
    def category_url(path_names)
      ("/categories/" + path_names.join("/")).tr(" ", "+")
    end
    
    def finder_link(spec, params = {})
      text = (params[:text] || spec.gsub(/\s+/, "&nbsp;"))
      spec = (params[:tag] ? "{#{spec}}" : spec).attribute_escape(true)
      klass = params[:class].to_s
      tip, tip_pos = params.values_at(:tip, :tip_pos)
      on_hover = tooltip_attributes(tip, tip_pos)
      "<span class=#{klass.inspect} onclick=\"finder_do('#{spec}')\" #{on_hover}>#{text}</span>"
    end
    
    def hidden_field(*args)
      "<div>#{super}</div>"
    end
    
    def marshal_product_links(product_ids_by_group)
      return [{}, {}] if product_ids_by_group.nil?
      
      checksums_by_product_id = {}
      product_ids_by_checksum = {}
      Indexer.image_checksums_for_product_ids(product_ids_by_group.values.flatten).each do |checksum, product_ids|
        checksums_by_product_id[product_ids.first] = checksum
        product_ids_by_checksum[checksum] = product_ids.first
      end
      
      images_by_checksum = Asset.all(:checksum => product_ids_by_checksum.keys).hash_by(:checksum)
      product_ids = checksums_by_product_id.keys
      
      product_links_by_group = {}
      product_ids_by_group.each do |group, g_product_ids|
        checksums = checksums_by_product_id.values_at(*(g_product_ids & product_ids)).uniq.sort_by do |checksum|
          Indexer.product_title(:image, product_ids_by_checksum[checksum])
        end
        product_links_by_group[group] = checksums.map do |checksum|
          product_link(product_ids_by_checksum[checksum], images_by_checksum[checksum])
        end
      end
      
      [product_links_by_group, product_ids]
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
    
    def product_data_table(infos)
      infos = infos.select { |info| info[:dad] }.sort_by { |info| info[:seq_num] }
      infos_by_property_id = infos.hash_by { |info| info[:id] }
      
      property_ids_by_section = {}
      infos.each { |info| (property_ids_by_section[info[:section]] ||= []) << info[:id] }
      
      html = ['<table id="common_values">']
      
      parity = :odd
      infos.map { |info| info[:section] }.uniq.each do |section|
        html << "<tr class=\"#{parity}\">"
        parity = (parity == :odd ? :even : :odd)
        
        html << "<td class=\"section\">#{section}</td>"
        html << "<td>"
        property_ids_by_section[section].each do |property_id|
          info = infos_by_property_id[property_id]
          html << <<-HTML
            <table summary="value data">
              <tr id="property_#{info[:id]}">
                <td class="icon"> #{property_icon(info)} </td>
                <td class="summary"> #{product_value_summary(info)} </td>
              </tr>
            </table>
          HTML
        end
        html << "</td>"
        
        html << "</tr>"
      end
      
      html << '</table>'
      
      html.join("\n")
    end
    
    def product_link(product_id, image)
      "<a id=\"product_#{product_id}\" class=\"product\" href=#{Indexer.product_url(product_id).inspect}> <img src=#{image.url(:tiny).inspect} alt=\"product\" /> </a>"
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
    
    def property_icon(info, position = :right)
      on_hover = tooltip_attributes(info[:name], position)
      "<img class=\"property_icon\" src=\"#{info[:icon_url]}\" alt=\"#{info[:name]}\" #{on_hover} />"
    end
    
    def tooltip(value, tip, position = :right)
      on_hover = tooltip_attributes(tip, position)
      "<span class=\"defined\" #{on_hover}>#{value}</span>"
    end
    
    def tooltip_attributes(tip, position = :right)
      on_hover = (tip.nil? ? nil : "onmouseover=\"tooltip_show(event, '#{tip.attribute_escape(true)}', '#{position}')\"")
      "#{on_hover} onmouseout=\"tooltip_hide()\""
    end
    
    def tooltip_list(name, values, position = :right)
      items = values.map { |value| value.split("\n") }.flatten.map { |value| "<li>#{value}</li>" }
      tooltip(name, "<ul>#{items.join}</ul>", position)
    end
  end
end
