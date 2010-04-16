# MongoSphinx, a full text indexing extension for MongoDB using
# Sphinx.

Gem::Specification.new do |spec|
  spec.platform = "ruby"
  spec.name = "mongosphinx"
  spec.homepage = "http://github.com/burke/mongosphinx"
  spec.version = "0.1"
  spec.authors = ["Burke Libbey", "Ryan Neufeld"]
  spec.email = ["burke@53cr.com", "ryan@53cr.com"]
  spec.summary = "A full text indexing extension for MongoDB using Sphinx."
  spec.files = ["README.rdoc", "mongosphinx.rb", "lib/multi_attribute.rb", "lib/mixins/properties.rb", "lib/mixins/indexer.rb", "lib/indexer.rb"]
  spec.require_path = "."
  spec.has_rdoc = true
  spec.executables = []
  spec.extra_rdoc_files = ["README.rdoc"]
  spec.rdoc_options = ["--exclude", "pkg", "--exclude", "tmp", "--all", "--title", "MongoSphinx", "--main", "README.rdoc"]
end
