# frozen_string_literal: true

require 'repl_completion'
require_relative './helper'

module TestReplCompletion
  class RequirePathsTest < TestCase
    def test_require_paths
      assert_include ReplCompletion::RequirePaths.require_completions('repl_com'), 'repl_completion'
      assert_include ReplCompletion::RequirePaths.require_completions('repl_com'), 'repl_completion/version'
      assert_equal ['repl_completion/version'], ReplCompletion::RequirePaths.require_completions('repl_completion/vers')
    end

    def test_require_relative_paths
      assert_include ReplCompletion::RequirePaths.require_relative_completions('test_re', binding), 'test_require_paths'
      assert_include ReplCompletion::RequirePaths.require_relative_completions('../repl_', binding), '../repl_completion/test_require_paths'
      root_path_binding = eval('binding', binding, File.join(__dir__, '../../Gemfile'), 1)
      assert_not_include ReplCompletion::RequirePaths.require_relative_completions('li', binding), 'lib/repl_completion'
      assert_include ReplCompletion::RequirePaths.require_relative_completions('li', root_path_binding), 'lib/repl_completion'
      # Incrementally complete deep path
      assert_include ReplCompletion::RequirePaths.require_relative_completions('li', root_path_binding), 'lib/repl_completion/'
      assert_not_include ReplCompletion::RequirePaths.require_relative_completions('li', root_path_binding), 'lib/repl_completion/version'
      assert_include ReplCompletion::RequirePaths.require_relative_completions('lib/', root_path_binding), 'lib/repl_completion/version'
    end
  end
end
