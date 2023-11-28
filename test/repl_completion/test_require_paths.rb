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
      assert_include ReplCompletion::RequirePaths.require_relative_completions('test_re', __FILE__), 'test_require_paths'
      assert_include ReplCompletion::RequirePaths.require_relative_completions('../repl_', __FILE__), '../repl_completion/test_require_paths'
      project_root = File.expand_path('../../Gemfile', __dir__)
      assert_not_include ReplCompletion::RequirePaths.require_relative_completions('li', __FILE__), 'lib/repl_completion'
      assert_include ReplCompletion::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_completion'
      # Incrementally complete deep path
      assert_include ReplCompletion::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_completion/'
      assert_not_include ReplCompletion::RequirePaths.require_relative_completions('li', project_root), 'lib/repl_completion/version'
      assert_include ReplCompletion::RequirePaths.require_relative_completions('lib/', project_root), 'lib/repl_completion/version'
    end
  end
end
