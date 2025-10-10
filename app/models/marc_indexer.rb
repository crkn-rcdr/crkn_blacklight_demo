# frozen_string_literal: true
require 'time'
$:.unshift './config'

class MarcIndexer < Blacklight::Marc::Indexer
  # this mixin defines lambda factory method get_format for legacy marc formats
  include Blacklight::Marc::Indexer::Formats

  HIER_DELIM = '|' # used by blacklight-hierarchy for splitting

  def initialize
    super

    settings do
      # type may be 'binary', 'xml', or 'json'
      provide "marc_source.type", "binary"
      # set this to be non-negative if threshold should be enforced
      provide 'solr_writer.max_skipped', -1
    end

    # https://github.com/ruby-marc/ruby-marc
    # https://github.com/traject/traject/blob/5d720e2ba0a277cf7af455763f520cd6a2d956c7/README.md?plain=1#L279
    to_field "id", extract_marc("001"), trim, first_only

    # 901 = "Is issue"  => Yes; otherwise (missing/different) => No
    to_field "is_issue" do |record, accumulator|
      v = record["901"]&.value&.strip
      accumulator.replace [ (v&.casecmp("Is issue")&.zero?) ? "Yes" : "No" ]
    end

    # --- serial_key: prefer 902$b; fallback to left side of 001 before '_' ---
    to_field "serial_key" do |record, acc|
      key = record["902"]&.subfields&.find { |sf| sf.code == 'b' }&.value&.strip
      if key && !key.empty?
        acc.replace [key]
      else
        id = record["001"]&.value
        acc.replace( id && id.include?('_') ? [id.split('_', 2).first] : [] )
      end
    end

    # --- serial_title: nil-safe split on ':' ---
    to_field "serial_title", extract_marc('245a'), first_only do |rec, acc|
      v = acc.first
      acc.replace(v && v.include?(':') ? [v.split(':', 2).first] : [])
    end

    # --- is_serial from 902$a "Is part of" (not 901) ---
    to_field "is_serial" do |record, acc|
      v = record["902"]&.subfields&.find { |sf| sf.code == 'a' }&.value&.strip
      acc.replace [(v&.casecmp("Is part of")&.zero?) ? "Yes" : "No"]
    end

    to_field 'marc_ss', get_xml
    to_field "all_text_timv", extract_all_marc_values do |r, acc|
      acc.replace [acc.join(' ')] # turn it into a single string
    end

    to_field "language_ssim", marc_languages("008[35-37]:041a:041d:")
    to_field "format", get_format

    #Look into this
    #to_field "isbn_tsim", extract_marc('020a', separator: nil) do |rec, acc|
    #  orig = acc.dup
    #  acc << orig
    #  acc.flatten!
    #  acc.uniq!
    #end

    to_field 'material_type_ssm', extract_marc('300a'), trim_punctuation

    # Title fields
    # full title
    to_field 'full_title_tsim', extract_marc('245ab')
    to_field 'full_title_ssm', extract_marc('245ab', alternate_script: false), trim_punctuation
    to_field 'full_title_vern_ssm', extract_marc('245ab', alternate_script: :only), trim_punctuation

    # primary title
    to_field 'title_tsim', extract_marc('245a')
    to_field 'title_ssm', extract_marc('245a', alternate_script: false), trim_punctuation
    to_field 'title_vern_ssm', extract_marc('245a', alternate_script: :only), trim_punctuation

    # subtitle
    to_field 'subtitle_tsim', extract_marc('245b')
    to_field 'subtitle_ssm', extract_marc('245b', alternate_script: false), trim_punctuation
    to_field 'subtitle_vern_ssm', extract_marc('245b', alternate_script: :only), trim_punctuation

    # Other Titles
    to_field 'title_addl_tsim',
      extract_marc(%W{
        246abcdefgnp
        240abcdefgklmnopqrs
        242abnp
        243abcdefgklmnopqrs
        247abcdefgnp
        730abcdefgklmnopqrst
        740anp
        830adfghklmnoprstvwxy
      }.join(':'))
    to_field 'title_si', marc_sortable_title

    # Author fields
    to_field 'author_tsim', extract_marc("100abcegqu:110abcdegnu:111acdegjnqu:130#{ATOZ}:700abcegqu:710abcdegnu:711acdegjnqu:720#{ATOZ}")
    to_field 'author_ssm', extract_marc("100abcdq:110#{ATOZ}:111#{ATOZ}:130#{ATOZ}:700abcegqu:710abcdegnu:711acdegjnqu:720#{ATOZ}", alternate_script: false)
    to_field 'author_vern_ssm', extract_marc("100abcdq:110#{ATOZ}:111#{ATOZ}:130#{ATOZ}:700abcegqu:710abcdegnu:711acdegjnqu:720#{ATOZ}", alternate_script: :only)

    # JSTOR isn't an author. Try to not use it as one
    to_field 'author_si', marc_sortable_author

    # Subject fields
    to_field 'subject_tsim', extract_marc(%W(
      600#{ATOZ}
      610#{ATOZ}
      611#{ATOZ}
      630#{ATOZ}
      647#{ATOZ}
      648#{ATOZ}
      650#{ATOZ}
      651#{ATOZ}
      653#{ATOZ}
      654#{ATOZ}
      655#{ATOZ}
      656#{ATOZ}
      657#{ATOZ}
      658#{ATOZ}
      662#{ATOZ}
      688#{ATOZ}
    ).join(':'))

    to_field 'subject_ssim', extract_marc(%W(
      600#{ATOZ}
      610#{ATOZ}
      611#{ATOZ}
      630#{ATOZ}
      647#{ATOZ}
      648#{ATOZ}
      650#{ATOZ}
      651#{ATOZ}
      653#{ATOZ}
      654#{ATOZ}
      655#{ATOZ}
      656#{ATOZ}
      657#{ATOZ}
      658#{ATOZ}
      662#{ATOZ}
      688#{ATOZ}
    ).join(':')), trim_punctuation

    # Published statement
    to_field 'published_ssm', extract_marc('260abcefg:264abc', alternate_script: false), trim_punctuation
    to_field 'published_vern_ssm', extract_marc('260abcefg:264abc', alternate_script: :only), trim_punctuation

    # Published Dates
    to_field 'pub_date_si',   marc_publication_date
    to_field 'pub_date_ssim', marc_publication_date

    # ----------------------------
    # CRKN additions
    # ----------------------------

    # Normalize helper (trim, drop trailing period, dedupe)
    clean_norm = lambda do |rec, acc|
      acc.map! { |s| s.to_s.strip.sub(/\.\z/, '') }
      acc.reject!(&:empty?)
      acc.uniq!
    end

    # Materials facet: TOP-LEVEL ONLY (999$a)
    to_field 'materials_ssim', extract_marc('999a'), clean_norm
    to_field 'materials_ssm',  extract_marc('999a'), clean_norm  # optional display

    # Optional: flat facet of all collection labels (both a and b levels)
    #to_field 'collection_ssim' do |rec, acc|
    #  vals = []
    #  rec.fields('999').each do |f|
    #    a = f['a']&.strip
    #    b = f['b']&.strip
    #    vals << a if a && !a.empty?
    #    vals << b if b && !b.empty?
    #  end
    #  vals.map! { |s| s.sub(/\.\z/, '') }
    #  acc.replace(vals.uniq)
    #end

    # Optional: human-readable path for display/debug
    to_field 'collection_path_tsim' do |rec, acc|
      rec.fields('999').each do |f|
        a = f['a']&.strip
        b = f['b']&.strip
        next unless a && !a.empty?
        a = a.sub(/\.\z/, '')
        if b && !b.empty?
          b = b.sub(/\.\z/, '')
          acc << "#{a}/#{b}"
        else
          acc << a
        end
      end
    end

    # Blacklight-hierarchy: single delimited field with permutations (A, A:B)
    to_field 'collection_hierarchy_ssim' do |rec, acc|
      # for each pair of 999 "a|b" where first is EN and second is FR
      # build hierarchical strings with pipe delimiter `|`
      # and prefix ONLY the root with an invisible language tag:
      #   \u2063enSerials|Newspapers
      #   \u2063frPublications en série|Journaux
      rec.fields('999').each_with_index do |f, idx|
        a = f['a']&.strip
        b = f['b']&.strip
        next unless a && !a.empty?

        lang_tag = idx.even? ? "\u2063en" : "\u2063fr"  # 1st=EN, 2nd=FR
        root = "#{lang_tag}#{a}"

        if b && !b.empty?
          acc << "#{root}|#{b}"
        else
          acc << root
        end
      end
    end

    # (Legacy, optional) Hierarchical paths using schema dynamic path types
    to_field 'collections_descendent_path' do |rec, acc|
      rec.fields('999').each do |f|
        a = f['a']&.strip
        b = f['b']&.strip
        next unless a && !a.empty?
        a = a.sub(/\.\z/, '')
        acc << a
        acc << "#{a}/#{b.sub(/\.\z/, '')}" if b && !b.empty?
      end
      acc.uniq!
    end

    to_field 'collections_ancestor_path' do |rec, acc|
      rec.fields('999').each do |f|
        a = f['a']&.strip
        b = f['b']&.strip
        next unless a && !a.empty?
        a = a.sub(/\.\z/, '')
        if b && !b.empty?
          b = b.sub(/\.\z/, '')
          acc << "#{a}/#{b}"
        else
          acc << a
        end
      end
      acc.uniq!
    end

    to_field 'depositor_tsim', extract_marc('590a')

    # Document Source
    to_field 'doc_source_tsim', extract_marc('533abcdu')

    # Rights Statement
    to_field 'rights_stat_tsim', extract_marc('540abcdfgqu')

    # Access Note
    to_field 'access_note_tsim', extract_marc('506abcdefgqu')

    # Original Version Note 534 - physical item desc
    to_field 'original_version_note_tsim', extract_marc('534abcefklmnoptxz')

    # Notes
    to_field 'notes_tsim', extract_marc(%W(
      500#{ATOZ}
      515#{ATOZ}
      546#{ATOZ}
    ).join(':'))

    # Source of Description
    to_field 'source_of_description_tsim', extract_marc(%W(588#{ATOZ}))

    # Series
    to_field 'title_series_tsim', extract_marc("440anpv:490av")

    to_field 'permalink_fulltext_ssm', extract_marc("856g")

    to_field 'date_added' do |record, accumulator|
      raw = record['998']&.value
      if raw
        # Parse MARC timestamp (e.g., "20240716103000.0005") and format only the date
        date = Time.strptime(raw[0..7], "%Y%m%d").utc.strftime("%Y-%m-%d")
        accumulator << date
      end
    end

    to_field 'date_edited' do |record, accumulator|
      raw = record['005']&.value
      if raw
        # Parse MARC timestamp (e.g., "20240716103000.0005") into ISO8601
        iso = Time.strptime(raw[0..13], "%Y%m%d%H%M%S").utc.iso8601
        accumulator << iso
      end
    end

    # URL Fields
    notfulltext = /abstract|description|sample text|table of contents/i
    to_field('url_fulltext_ssm') do |rec, acc|
      rec.fields('856').each do |f|
        case f.indicator2
        when '0'
          f.find_all{|sf| sf.code == 'u'}.each do |url|
            acc << url.value
          end
        when '2'
          # do nothing
        else
          z3 = [f['z'], f['3']].join(' ')
          unless notfulltext.match(z3)
            acc << f['u'] unless f['u'].nil?
          end
        end
      end
    end

    # Very similar to url_fulltext_display. Should DRY up.
    to_field 'url_suppl_ssm' do |rec, acc|
      rec.fields('856').each do |f|
        case f.indicator2
        when '2'
          f.find_all{|sf| sf.code == 'u'}.each do |url|
            acc << url.value
          end
        when '0'
          # do nothing
        else
          z3 = [f['z'], f['3']].join(' ')
          if notfulltext.match(z3)
            acc << f['u'] unless f['u'].nil?
          end
        end
      end
    end

    # Call Number fields
    to_field 'lc_callnum_ssm', extract_marc('050ab'), first_only

    first_letter = lambda {|rec, acc| acc.map!{|x| x[0]} }
    to_field 'lc_1letter_ssim', extract_marc('050ab'), first_only, first_letter, translation_map('callnumber_map')

    alpha_pat = /\A([A-Z]{1,3})\d.*\Z/
    alpha_only = lambda do |rec, acc|
      acc.map! do |x|
        (m = alpha_pat.match(x)) ? m[1] : nil
      end
      acc.compact! # eliminate nils
    end
    to_field 'lc_alpha_ssim', extract_marc('050a'), alpha_only, first_only

    to_field 'lc_b4cutter_ssim', extract_marc('050a'), first_only
  end
end
