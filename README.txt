= ModelSet

ModelSet is a array-like class for dealing with sets of ActiveRecord models. ModelSet
stores a list of ids and fetches the models lazily only when necessary. You can also add
conditions in SQL to further limit the set. Currently I support alternate queries using
the Solr search engine through a subclass, but I plan to abstract this out into a "query
engine" class that will support SQL, Solr, Sphinx, and eventually, other query methods
(possibly raw RecordCache hashes and other search engines).

== INSTALL:

  sudo gem install model_set

== USAGE: 

class RobotSet < ModelSet
end

set1 = RobotSet.new([1,2,3,4]) # doesn't fetch the models

set1.each do |model| # fetches all 
  # do something
end

set2 = RobotSet.new([1,2])

set3 = set1 - set2
set3.ids
# => [3,4]

set3 << Robot.find(5)
set3.ids
# => [3,4,5]

== REQUIREMENTS:

 * deep_clonable
 * ordered_set
 * active_record

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
