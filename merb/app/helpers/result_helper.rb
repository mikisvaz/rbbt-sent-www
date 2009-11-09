module Merb
  module ResultHelper

    def gene_profile(gene, values)
      s = <<-EOF
              <tr>
                <td>
                  <a href='#{gene[:url]}' title='#{gene[:synonyms].join(", ")}'>
                    #{gene[:name]}
                  </a>
                </td>
      EOF
      values.each{|v|
        s += <<-EOF
                <td #{ v == values.max ?  "class='max'":""}>
                  #{"%4.4g" % v}
                </td>
        EOF
      }

      s += <<-EOF
              </tr>

      EOF
      s
    end

    def go_info(go)
      s = <<-EOF
      <a href="http://amigo.geneontology.org/cgi-bin/amigo/go.cgi?view=details&amp;query=#{go}">#{go}:</a> #{Job::Info::goid2name(go) || go}
      EOF
      s
    end
     
    def pager(pages,page,anchor = nil, words = [])

      anchor = "#" + anchor if anchor

      w = ""
      w = "&words=#{words.join(" ")}" if words.any?

      markaby do
        

        a "<< First", :href => "?page=1" + w + anchor if pages > 5 
        a "< Prev", :href => "?page=#{page-1}" + w + anchor if pages > 5 && page > 1

        range_start = [1,page - 3].max
        range_end = [pages,page + 3].min


        text " . " if pages > 5
        (range_start..range_end).each{|i|
          if page != i
            a i, :href => "?page=#{ i }" + w + "#literature" 
          else
            text i
          end
          text " . "
        }

        a "Next >", :href => "?page=#{ page+1}" + w + anchor if pages > 5 && page < pages
        a "Last [#{pages}] >>", :href => "?page=#{ pages }" + w + anchor if pages > 5 

      end
    end
 
    def hilight(text, names = nil,words = nil, custom=nil)
      words  = ['NO_MATCH'] unless words && words.any?
      custom = ['NO_MATCH'] unless custom && custom.any?
      names  = ['NO_MATCH'] unless names && names.any?
      names_re  = names.compact.sort{|a,b| b.length <=> a.length}.collect{|w| Regexp.quote(w)}.join("|")
      words_re  = words.compact.sort{|a,b| b.length <=> a.length}.collect{|w| Regexp.quote(w)}.join("|")
      custom_re = custom.compact.sort{|a,b| b.length <=> a.length}.collect{|w| Regexp.quote(w)}.join("|")
      text.gsub(/(^|[^a-z\-_])(#{names_re})(?![a-oq-z\-_])/i,'\1<span class="gene_mention">\2</span>').
        gsub(/(^|[^a-z\-_])(#{words_re})(?![a-oq-z\-_])/i,'\1<span class="feature_word">\2</span>').
        gsub(/(^|[^a-z\-_])(#{custom_re})(?![a-oq-z\-_])/i,'\1<span class="custom_query">\2</span>')
    end

    def literature_entry(pmid, value, associations = [],all_genes= [], gene_info= [], words= [], stems= [])
      genes = associations.keys.select{|gene| associations[gene].include? pmid} if associations
      url, title, abstract = Job::Info::pmid_info(pmid)

      s =<<-EOF
         <tr>
           <td class="article" id="tip_anchor_article_#{pmid}">
             <a class="article tip_anchor" href="#{ url }">#{ pmid }</a>
               <div class="tooltip" id="tip_article_#{pmid}">
                #{ hilight(abstract, all_genes.collect{|g| gene_info[g][:synonyms]}.flatten, words.collect{|w| w.split(/\s/).collect{|s| stems[s] }}.flatten) }
               </div></td>
             <td class="title">#{title}</td>
      EOF

      if value.kind_of? Array
        value.each{|v|
          s += <<-EOF
                  <td class="score">
                    #{"%1.4f" % v}
                  </td>
          EOF
        }
      else
        s += <<-EOF
                  <td class="score">
                    #{"%1.4f" % value}
                  </td>
          EOF
      end

      if associations.keys.any?  
        s += <<-EOF
             <td class='genes'> 
               #{
                 genes.collect{|g| 
                   info = gene_info[g]
                   "<a title='#{info[:synonyms].join(", ")}' href='#{info[:url]}'> #{info[:name]} </a>"
                   }.join(", ")
                 } 
                 
               </td> 
          EOF
      end

      s
    end
  end
end # Merb
