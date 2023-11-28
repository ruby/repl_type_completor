# frozen_string_literal: true

require 'repl_type_completor'
require_relative './helper'

module TestReplTypeCompletor
  class RequirePathsTest < TestCase
    def test_require_paths
      assert_include ReplTypeCompletor::RequirePaths.require_completions('repl_type_com'), 'repl_type_completor'
      assert_include ReplTypeCompletor::RequirePaths.require_completions('repl_type_com'), 'repl_type_completor/version'
      assert_equal ['repl_type_completor/version'], ReplTypeCompletor::RequirePaths.require_completions('repl_type_completor/vers')
    end

    def test_require_relative_paths
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('test_re', __FILE__), 'test_require_paths'
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('../repl_', __FILE__), '../repl_type_completor/test_require_paths'
      project_root = File.expand_path('../../Gemfile', __dir__)
      assert_not_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', __FILE__), 'lib/repl_type_completor'
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_type_completor'
      # Incrementally complete deep path
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_type_completor/'
      assert_not_include ReplTypeCompletor::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_type_completor/version'
      assert_include ReplTypeCompletor::RequirePaths.require_relative_completions('lib/', project_root), 'lib/repl_type_completor/version'
    end
  end
end
