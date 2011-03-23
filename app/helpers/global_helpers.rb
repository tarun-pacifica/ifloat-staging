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
    
    def breadcrumbs(phrase, category_path_names)
      crumbs = [category_link([], "All Categories", true)]
      
      crumbs << category_link([], "\"#{phrase}\"") unless phrase.nil?
      
      crumbs += category_path_names.size.times.map { |i| category_link(category_path_names[0, i + 1]) }
      
      filters = (JSON.parse(params["filters"]) rescue [])
      filters.each_with_index do |filter, i|
        property_id, unit, value, label = filter
        label = (label.nil? ? value : label.gsub(Application::RANGE_SEPARATOR, "-"))
        crumbs << category_link(category_path_names, label, false, filters[0, i + 1])
      end
      
      crumbs << '<a class="filter" href="#" onclick="category_filters_show(); return false">Filter your results</a>' if category_path_names.size == 2
      
      crumbs.join(" &rarr; ")
    end
    
    def category_link(path_names, name = nil, ignore_find = false, filters = [])
      url = ("/categories/" + path_names.join("/")).tr(" ", "+")
      
      query_params = []
      
      find_phrase = params["find"]
      query_params << "find=#{find_phrase}" unless ignore_find or find_phrase.nil?
      query_params << "filters=#{URI.encode(filters.to_json)}" unless filters.empty?
      
      url += "?#{query_params.join('&')}" unless query_params.empty?
      name ||= path_names.last
      on_hover = tooltip_attributes(Indexer.category_definition(name))
      "<a href=#{url.inspect} #{on_hover}>#{Merb::Parse.escape_xml(name)}</a>"
    end
    
    def finder_link(spec, params = {})
      text = (params[:text] || spec.gsub(/\s+/, "&nbsp;"))
      spec = (params[:tag] ? "{#{spec}}" : spec).attribute_escape(true)
      klass = params[:class].to_s
      tip, tip_pos = params.values_at(:tip, :tip_pos)
      on_hover = tooltip_attributes(tip, tip_pos)
      "<span class=#{klass.inspect} onclick=\"finder_do('#{spec}')\" #{on_hover}>#{text}</span>"
    end
    
    def friendly_list(items, andor)
      return fallback if items.empty?
      return items.first if items.size == 1
      items[0..-2].join(", ") + " #{andor} #{items.last}"
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
      html = ['<table summary="properties">']
      html += infos.map do |info|
        <<-HTML
          <tr id="property_#{info[:id]}">
            <td class="icon"> #{property_icon(info)} </td>
            <td class="summary"> #{product_value_summary(info)} </td>
          </tr>
        HTML
      end
      html << '</table>'
      html.join("\n")
    end
    
    def product_link(product_id, image)
      "<a id=\"product_#{product_id}\" href=#{Indexer.product_url(product_id).inspect}> <img src=#{image.url(:tiny).inspect} alt=\"product\" /> </a>"
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
