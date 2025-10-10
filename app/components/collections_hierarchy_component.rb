# app/components/collections_hierarchy_component.rb
# frozen_string_literal: true

class CollectionsHierarchyComponent < Blacklight::Hierarchy::FacetFieldListComponent
  # show EN (odd indexes) or FR (even indexes) based on UI language
  def tree
    t = super
    return t unless t.is_a?(Hash)

    keep_parity = (language == 'fr') ? 0 : 1 # 0 = FR roots, 1 = EN roots

    filter_top_level(t, keep_parity)
  end

  private

  def filter_top_level(subtree, keep_parity)
    filtered = {}

    string_keys = subtree.keys.select { |k| k.is_a?(String) }
    string_keys.each_with_index do |key, idx|
      next unless (idx % 2) == keep_parity
      filtered[key] = subtree[key]
    end

    # Preserve non-string entries like metadata stored under symbol keys.
    subtree.each do |key, value|
      next if key.is_a?(String)
      filtered[key] = value
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
end
