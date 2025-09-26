class CollectionItemsComponent < ViewComponent::Base
  def initialize(documentId:, page: 1, per_page: 10)
    @documentId = documentId
    @page = page.to_i
    @per_page = per_page.to_i

    rsolr = RSolr.connect url: 'http://public:hdwi389e8d!ds@4.229.225.26/solr/blacklight_marc_demo'

    start = (@page - 1) * @per_page

    @response_data = rsolr.get 'select', params: {
      q: "serial_key:#{@documentId}",
      start: start,
      rows: @per_page
    }

    @collection_items = @response_data['response']['docs']
    @total_items = @response_data['response']['numFound']
    @total_pages = (@total_items.to_f / @per_page).ceil
  end
end
