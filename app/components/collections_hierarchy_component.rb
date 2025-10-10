# app/components/collections_hierarchy_component.rb
# frozen_string_literal: true

class CollectionsHierarchyComponent < Blacklight::Hierarchy::FacetFieldListComponent
  class << self
    def strip_language_prefix(value)
      return value unless value.respond_to?(:to_s)

      cleaned = value.to_s.sub(/\A[\p{Cf}\s]+/, '')
      cleaned.sub(/\A(fr|en)(?=[A-Z])/, '')
    end
  end

  def tree
    t = super
    return t unless t.is_a?(Hash)

    filter_top_level(t)
  end

  private

  def filter_top_level(subtree)
    filtered = {}

    subtree.each do |key, value|
      if key.is_a?(String)
        filtered[key] = value if show_node_for_current_language?(key, value)
      else
        filtered[key] = value
      end
    end

    filtered
  end

  def language
    if helpers.respond_to?(:content_lang)
      helpers.content_lang.presence || 'en'
    else
      helpers.params[:lang].presence || I18n.locale.to_s
    end
  end

  def show_node_for_current_language?(key, node)
    label = node.fetch(:_, nil)&.respond_to?(:value) ? node[:_].value : key
    prefix = language_prefix_for(label)
    return true if prefix.nil?

    prefix == preferred_language_prefix
  end

  def preferred_language_prefix
    # Source data prefixes "fr" values for English labels and "en" for French labels.
    language == 'fr' ? 'en' : 'fr'
  end

  def language_prefix_for(label)
    return nil unless label.respond_to?(:to_s)

    stripped = label.to_s.sub(/\A[\p{Cf}\s]+/, '')
    match = stripped.match(/\A(fr|en)(?=[A-Z])/)
    match && match[1]
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
