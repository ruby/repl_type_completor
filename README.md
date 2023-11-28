# ReplTypeCompletor

ReplTypeCompletor is a type based completor for REPL.
It uses RBS type information, performs static type analytics, uses dynamic runtime information from binding.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install UPDATE_WITH_YOUR_GEM_NAME_PRIOR_TO_RELEASE_TO_RUBYGEMS_ORG

## Usage

Require the library
```ruby
require 'repl_type_completor'
```

Load RBS with one of these. It will load core library signatures, `./rbs_collection.yaml` and `./sig/**/*.rbs`.
```ruby
ReplTypeCompletor.preload_rbs # Recommended. Preload using thread
ReplTypeCompletor.load_rbs # Could take a seconds in large projects
```

Now you can get completion candidates.
```ruby
array = [1, 2, 3]
class String; def upupup; end; end
result = ReplTypeCompletor.analyze('array.map do str = _1.chr; str.up', binding: binding)
result.completion_candidates #=> ["case", "case!", "to", "upup"]
result.doc_namespace('case') #=> "String#upcase"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/repl_type_completor.

When something is wrong, these methods will provide some debug information.
```ruby
ReplTypeCompletor.info
ReplTypeCompletor.rbs_load_started?
ReplTypeCompletor.rbs_loaded?
ReplTypeCompletor.rbs_load_error
ReplTypeCompletor.last_completion_error
ReplTypeCompletor.analyze(code_to_complete, binding: binding)
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
