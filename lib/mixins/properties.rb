# MongoSphinx, a full text indexing extension for MongoDB using
# Sphinx.
#
# This file contains the MongoMapper::Mixins::Properties module.

# Patches to the CouchRest library.

module MongoMapper # :nodoc:
  module Mixins # :nodoc:

    # Patches to the CouchRest Properties module: Adds the "attributes" method 
    # plus some fulltext relevant stuff.
    #
    # Samples:
    #
    #   data = SERVER.default_database.view('CouchSphinxIndex/couchrests_by_timestamp')
    #   rows = data['rows']
    #   post = Post.new(rows.first)
    #
    #   post.attributes
    #   => {:tags=>"one, two, three", :updated_at=>Tue Jun 09 14:45:00 +0200 2009,
    #       :author=>nil, :title=>"First Post",
    #       :created_at=>Tue Jun 09 14:45:00 +0200 2009,
    #       :body=>"This is the first post. This is the [...] first post. "}
    #
    #   post.fulltext_attributes
    #   => {:title=>"First Post", :author=>nil,
    #       :created_at=>Tue Jun 09 14:45:00 +0200 2009
    #       :body=>"This is the first post. This is the [...] first post. "}
    #
    #   post.sphinx_id
    #   => "921744775"
    #   post.id
    #   => "Post-921744775"

    module Properties

      # Returns a Hash of all attributes allowed to be indexed. As a side
      # effect it sets the fulltext_keys variable if still blank or empty.

      def fulltext_attributes
        clas = self.class

        if not clas.fulltext_keys or clas.fulltext_keys.empty?
          clas.fulltext_keys = self.attributes.collect { |k,v| k.intern } 
        end

        return self.attributes.reject do |k, v|
          not (clas.fulltext_keys.include? k.intern)
        end
      end
      
      # Returns a Hash of all Sphinx attributes to be used for filtering
      # Note: fulltext_attributes really should be fulltext_fields
      
      def attribute_fields
        clas = self.class
          
        return self.attributes.reject do |k, v|
          not (clas.attribute_keys.include? k.intern)
        end
      end

      # Returns the numeric part of the document ID (compatible to Sphinx).

      def sphinx_id
        raise "Deprecated"
        if (match = self.id.match(/#{self.class}-([0-9]+)/))
          return match[1]
        else
          return nil
        end
      end
    end
  end
end
