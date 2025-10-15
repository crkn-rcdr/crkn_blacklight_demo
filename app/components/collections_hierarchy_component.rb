# app/components/collections_hierarchy_component.rb
# frozen_string_literal: true

class CollectionsHierarchyComponent < Blacklight::Hierarchy::FacetFieldListComponent
  class << self
    def strip_language_prefix(value)
      cleaned = value.to_s.sub(/\A[\p{Cf}\s]+/, '')
      cleaned.split('/').last.to_s
    end
  end

  def render?
    return false unless field_visible_for_current_language?
    super
  end

  private

  def tree
    @tree ||= build_tree(items)
  end

  def field_visible_for_current_language?
    suffix = language_suffix
    return true if suffix.nil?

    current = preferred_language_code
    (suffix == :fr && current == :fr) || (suffix == :en && current == :en)
  end

  def build_tree(items)
    tree = {}
    sorted = items.sort_by { |item| path_segments(facet_value(item)).length }

    sorted.each do |item|
      parts = path_segments(facet_value(item))
      next if parts.empty?

      current = tree
      parts.each_with_index do |part, idx|
        current[part] ||= {}
        node = current[part]
        node[:_] = item if idx == parts.length - 1
        current = node
      end
    end

    tree
  end

  def items
    return @items if defined?(@items)

    raw_items =
      if instance_variable_defined?(:@facet_field) && @facet_field&.respond_to?(:items)
        @facet_field.items
      elsif respond_to?(:facet_field) && (facet_field_value = facet_field).respond_to?(:items)
        facet_field_value.items
      elsif instance_variable_defined?(:@field_config) && @field_config.respond_to?(:items)
        @field_config.items
      elsif instance_variable_defined?(:@field_config) && @field_config.respond_to?(:[])
        @field_config[:items]
      end

    @items = Array(raw_items || [])
  end

  def language_suffix
    name = @field_name.to_s
    return :fr if name.match?(/(^|_)fr(_|$)/i)
    return :en if name.match?(/(^|_)en(_|$)/i)

    nil
  end

  def preferred_language_code
    lang =
      if helpers.respond_to?(:current_ui_language_code)
        helpers.current_ui_language_code
      elsif helpers.respond_to?(:content_lang)
        helpers.content_lang
      end

    lang = helpers.params[:lang] if lang.blank? && helpers.respond_to?(:params)
    lang = I18n.locale.to_s if lang.blank?

    lang.to_s.start_with?('fr') ? :fr : :en
  end

  def facet_value(item)
    return '' if item.nil?

    if item.respond_to?(:value)
      item.value.to_s
    elsif item.respond_to?(:[]) && item[:value]
      item[:value].to_s
    elsif item.is_a?(Array)
      item.first.to_s
    else
      item.to_s
    end
  end

  def path_segments(value)
    value.to_s.split('/').map { |part| part.to_s.strip }.reject(&:blank?)
  end

  class NodeComponent < Blacklight::Hierarchy::FacetFieldComponent
    def call
      ul_id = "b-h-#{SecureRandom.alphanumeric(10)}"
      parts = []
      parts << caret_button(ul_id) if subset.any?
      parts << render_node_body
      parts << render_children(ul_id) if subset.any?

      data_attrs = controller_name.present? ? { controller: controller_name } : nil

      helpers.content_tag(:li, class: li_class, data: data_attrs, role: 'treeitem') do
        helpers.safe_join(parts.compact)
      end
    end

    private

    def render_node_body
      if item.nil?
        CollectionsHierarchyComponent.strip_language_prefix(@key)
      elsif qfacet_selected?
        helpers.render(CollectionsHierarchyComponent::SelectedValueComponent.new(field_name: field_name, item: item))
      else
        helpers.render(CollectionsHierarchyComponent::ValueComponent.new(field_name: field_name, item: item, id: id))
      end
    end

    def render_children(ul_id)
      child_nodes = subset.keys.map do |subkey|
        helpers.render(self.class.new(field_name: field_name, tree: subset[subkey], key: subkey))
      end

      helpers.content_tag(:ul, helpers.safe_join(child_nodes), id: ul_id, class: 'collapse', data: { 'b-h-collapsible-target': 'list' }, role: 'group')
    end

    def caret_button(ul_id)
      icon = helpers.content_tag(:span, '', class: 'facet-caret', aria: { hidden: true })

      helpers.button_tag(
        icon,
        type: 'button',
        class: 'facet-caret-toggle',
        aria: {
          expanded: 'false',
          controls: ul_id,
          label: I18n.t('blacklight.search.facets.hierarchy.toggle', default: 'Toggle subgroup')
        },
        data: {
          action: 'click->b-h-collapsible#toggle',
          'b-h-collapsible-target': 'button',
          toggle: 'collapse',
          'bs-toggle': 'collapse',
          target: "##{ul_id}",
          'bs-target': "##{ul_id}"
        }
      )
    end
  end

  class ValueComponent < Blacklight::Hierarchy::QfacetValueComponent
    private

    def label_value
      CollectionsHierarchyComponent.strip_language_prefix(super)
    end
  end

  class SelectedValueComponent < Blacklight::Hierarchy::SelectedQfacetValueComponent
    private

    def label_value
      CollectionsHierarchyComponent.strip_language_prefix(super)
    end
  end
end


