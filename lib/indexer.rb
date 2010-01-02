# MongoSphinx, a full text indexing extension for MongoDB using
# Sphinx.
#
# This file contains the MongoSphinx::Indexer::XMLDocset and
# MongoSphinx::Indexer::XMLDoc classes.

# Namespace module for the MongoSphinx gem.

module MongoSphinx #:nodoc:

  # Module Indexer contains classes for creating XML input documents for the
  # indexer. Each Sphinx index consists of a single "sphinx:docset" with any
  # number of "sphinx:document" tags.
  #
  # The XML source can be generated from an array of CouchRest objects or from
  # an array of Hashes containing at least fields "classname" and "_id"
  # as returned by MongoDB view "MongoSphinxIndex/couchrests_by_timestamp".
  #
  # Sample:
  #
  #   rows = [{ 'name' => 'John', 'phone' => '199 43828',
  #             'classname' => 'Address', '_id' => 'Address-234164'
  #           },
  #           { 'name' => 'Sue', 'mobile' => '828 19439',
  #             'classname' => 'Address', '_id' => 'Address-422433'
  #          }
  #   ]
  #   puts MongoSphinx::Indexer::XMLDocset.new(rows).to_s
  #
  #   <?xml version="1.0" encoding="utf-8"?>
  #   <sphinx:docset>
  #     <sphinx:schema>
  #       <sphinx:attr name="csphinx-class" type="multi"/>
  #       <sphinx:field name="classname"/>
  #       <sphinx:field name="name"/>
  #       <sphinx:field name="phone"/>
  #       <sphinx:field name="mobile"/>
  #       <sphinx:field name="created_at"/>
  #     </sphinx:schema>
  #     <sphinx:document id="234164">
  #       <csphinx-class>336,623,883,1140</csphinx-class>
  #       <classname>Address</classname>
  #       <name><![CDATA[[John]]></name>
  #       <phone><![CDATA[[199 422433]]></phone>
  #       <mobile><![CDATA[[]]></mobile>
  #       <created_at><![CDATA[[]]></created_at>
  #     </sphinx:document>
  #     <sphinx:document id="423423">
  #       <csphinx-class>336,623,883,1140</csphinx-class>
  #       <classname>Address</classname>
  #       <name><![CDATA[[Sue]]></name>
  #       <phone><![CDATA[[]]></phone>
  #       <mobile><![CDATA[[828 19439]]></mobile>
  #       <created_at><![CDATA[[]]></created_at>
  #     </sphinx:document>
  #   </sphinx:docset>"

  module Indexer

    # Class XMLDocset wraps the XML representation of a document to index. It
    # contains a complete "sphinx:docset" including its schema definition.

    class XMLDocset

      # Objects contained in document set.

      attr_reader :xml_docs

      # XML generated for opening the document.

      attr_reader :xml_header

      # XML generated for closing the document.

      attr_reader :xml_footer

      # Creates a XMLDocset object from the provided data. It defines a
      # superset of all fields of the classes to index objects for. The class
      # names are collected from the provided objects as well.
      #
      # Parameters:
      #
      # [data] Array with objects of type CouchRest::Document or Hash to create XML for

      def initialize(rows = [])
        raise ArgumentError, 'Missing class names' if rows.nil?

        xml = '<?xml version="1.0" encoding="utf-8"?>'

        xml << "<sphinx:docset><sphinx:schema>\n"

        @xml_docs = []
        classes = []
        
        valid_attr_types = {Integer => "int", Time => "timestamp", ActiveSupport::TimeWithZone => "timestamp", String => "str2ordinal", Boolean => "bool"} #, "float", "multi"}

        rows.each do |row|
          object = nil

          if row.kind_of? MongoMapper::Document
            object = row
          elsif row.kind_of? Hash
            row = row['value'] if row['classname'].nil?

            if row and (class_name = row['classname'])
              object = eval(class_name.to_s).new(row) rescue nil
            end
          end

          if object and object._sphinx_id
            classes << object.class if not classes.include? object.class
            @xml_docs << XMLDoc.from_object(object)
          end
        end

        field_names = classes.collect { |clas| clas.fulltext_keys rescue []
                        }.flatten.uniq

        field_names.each do |key, value|
          xml << "  <sphinx:field name=\"#{key}\"/>\n"
        end
        
        attribute_names = classes.collect { |clas|
          clas.attribute_keys.collect { |attr_field| 
            {:key => attr_field, :type => clas.keys[attr_field].type}} rescue []
                            }.flatten.uniq
        
        attribute_names.each do |key, value|
          xml << "  <sphinx:attr name=\"#{key[:key]}\" type=\"#{valid_attr_types[key[:type]]}\"/>\n"
        end

        xml << '  <sphinx:field name="classname"/>'
        xml << '  <sphinx:attr name="csphinx-class" type="multi"/>'

        xml << '</sphinx:schema>'

        @xml_header = xml
        @xml_footer = "</sphinx:docset>\n"
      end
      
      # Add rows (in case we're paginating)
      
      def add_rows(rows = [], flush = false)
        # We present this option for large result sets
        @xml_docs = [] if flush
        
        rows.each do |row|
          object = nil

          if row.kind_of? MongoMapper::Document
            object = row
          elsif row.kind_of? Hash
            row = row['value'] if row['classname'].nil?

            if row and (class_name = row['classname'])
              object = eval(class_name.to_s).new(row) rescue nil
            end
          end

          if object and object._sphinx_id
            @xml_docs << XMLDoc.from_object(object)
          end
        end
      end

      # Returns the encoded data as XML.
      
      def to_xml
        return to_s
      end

      # Returns the encoded data as XML.
      
      def to_s
        return self.xml_header + self.xml_docs.join + self.xml_footer
      end
    end

    # Class XMLDoc wraps the XML representation of a single document to index
    # and contains a complete "sphinx:document" tag.

    class XMLDoc

      # Returns the ID of the encoded data.

      attr_reader :id

      # Returns the class name of the encoded data.

      attr_reader :class_name

      # Returns the encoded data.

      attr_reader :xml

      # Creates a XMLDoc object from the provided CouchRest object.
      #
      # Parameters:
      #
      # [object] Object to index

      def self.from_object(object)
        raise ArgumentError, 'Missing object' if object.nil?
        raise ArgumentError, 'No compatible ID' if (id = object._sphinx_id).nil?

        return new(id, object.class.to_s, object.fulltext_attributes, object.attribute_fields)
      end

      # Creates a XMLDoc object from the provided ID, class name and data.
      #
      # Parameters:
      #
      # [id] ID of the object to index
      # [class_name] Name of the class
      # [data] Hash with the properties to index

      def initialize(id, class_name, properties, attributes)
        raise ArgumentError, 'Missing id' if id.nil?
        raise ArgumentError, 'Missing class_name' if class_name.nil?

        xml = "<sphinx:document id=\"#{id}\">\n"

        xml << '  <csphinx-class>'
        xml << MongoSphinx::MultiAttribute.encode(class_name)
        xml << "</csphinx-class>\n"
        xml << "  <classname>#{class_name}</classname>\n"

        properties.each do |key, value|
          next if value.nil?
          if [Time,ActiveSupport::TimeWithZone].include?value.class
            xml << "  <#{key}>#{value.to_i}</#{key}>\n"
          else
            xml << "  <#{key}><![CDATA[[#{(value.is_a?Array and value.join(' ')) || value.unpack('U*').map {|n| n.xchr}.join unless value.nil?}]]></#{key}>\n"
          end
        end
        
        attributes.each do |key, value|
          # Skip this if we already spit it out (I think)
          next if properties.keys.include?key
          # Convert to necessary format
          if [Time,ActiveSupport::TimeWithZone].include?value.class
            xml << "  <#{key}>#{value.to_i}</#{key}>\n"
          else
            xml << "  <#{key}>#{value}</#{key}>\n"
          end
        end

        xml << "</sphinx:document>\n"

        @xml = xml

        @id = id
        @class_name = class_name
      end

      # Returns the encoded data as XML.
      
      def to_xml
        return to_s
      end

      # Returns the encoded data as XML.
      
      def to_s
        return self.xml
      end
    end
  end
end
