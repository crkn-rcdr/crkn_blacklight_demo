# See: https://github.com/pulibrary/orangelight/blob/main/app/helpers/application_helper.rb
require 'cgi'  # For URL escaping

module ApplicationHelper
  # Ensure document links carry current search query and language by default.
  # This overrides Blacklight's helper in the view context.
  def url_for_document(document, options = {})
    opts = options.symbolize_keys
    opts[:q] = params[:q] if params[:q].present? && !opts.key?(:q)
    opts[:lang] = params[:lang] if params[:lang].present? && !opts.key?(:lang)
    solr_document_path(document, opts)
  end
  def render_icon(var)
    "<span title='#{var.parameterize}' class='icon icon-#{var.parameterize}' aria-hidden='true'></span>"
  end
  def format_render(var)
    "<span class='format-text'>#{var.parameterize}</span>"
  end
  def format_icon(args)
    format_str = args[:document][args[:field]].join(', ').to_s
    if format_str.include?('Serial')
      if args[:document][:id].include?('N')
        format_str = 'newspaper-issue'
      else
        format_str = 'journal-issue'
      end
    end
    icon = render_icon(format_str)
    formats = format_render(format_str)
    content_tag :ul do
      content_tag :li, " #{icon} #{formats} ".html_safe, class: 'blacklight-format', dir: 'ltr'
    end
  end
  def value_link(args)
    value_str = Array(args[:document][args[:field]]).join(', ')
    content_tag :a, "#{value_str}".html_safe, href: value_str, dir: 'ltr'
  end
  def format_text(args)
    args[:document][args[:field]].map! do |item|
      item.gsub(/https?:\/\/\S+/) do |url|
        "<a href=\"#{url}\" target=\"_blank\">#{url}</a>"
      end
    end
    value_str = Array(args[:document][args[:field]]).join('<br/>')
    value_str.sub!(/<br\/>$/, '')
    content_tag :p, "#{value_str}".html_safe, dir: 'ltr'
  end
  def format_facet(args)
    field = args[:field].to_s
    args[:document][args[:field]].map! do |value|
      escaped_value = CGI.escape(value.to_s)
      "<a href=\"/catalog?f%5B#{field}_str%5D%5B%5D=#{escaped_value}&q=&search_field=all_fields\">#{value}</a>"
    end
    value_str = Array(args[:document][args[:field]]).join('<br/>')
    value_str.sub!(/<br\/>$/, '')
    content_tag :p, "#{value_str}".html_safe, dir: 'ltr'
  end
  def format_date(args)
    Time.parse(args[:document][args[:field]].to_s).strftime("%Y-%m-%d")
  rescue
    args[:document][args[:field]].to_s # Fallback to original if parsing fails
  end

  # Build language-aware collection breadcrumbs from hierarchy facet values.
  def collection_breadcrumb_paths(document)
    values = Array(document['collection_hierarchy_ssim']).compact
    return [] if values.empty?

    lang = current_ui_language_code
    preferred = values.select { |val| hierarchy_value_language(val) == lang }
    preferred = values if preferred.empty?

    preferred.map do |value|
      parts = value.split('|')
      parts.each_index.map do |idx|
        raw_segment = parts[idx]
        label = idx.zero? ? CollectionsHierarchyComponent.strip_language_prefix(parts.first) : raw_segment
        { label: label.to_s.strip, value: parts[0..idx].join('|') }
      end
    end
  end

  def collection_breadcrumb_url(facet_value)
    params_hash = { 'f[collection_hierarchy_ssim][]' => facet_value }
    lang = current_ui_language_param
    params_hash[:lang] = lang if lang.present?
    search_action_path(params_hash)
  end

  def current_ui_language_param
    if respond_to?(:content_lang)
      val = content_lang
      return val if val.present?
    end
    return params[:lang] if params[:lang].present?

    I18n.locale.to_s
  end

  def current_ui_language_code
    current_ui_language_param.to_s.start_with?('fr') ? 'fr' : 'en'
  end

  def hierarchy_value_language(value)
    first = value.to_s.split('|').first
    return nil unless first

    stripped = first.sub(/\A[\p{Cf}\s]+/, '')
    match = stripped.match(/\A(fr|en)/i)
    match && match[1].downcase
  end
end
