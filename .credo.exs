%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: ["deps/", "_build/"]
      },
      strict: true,
      checks: [
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.Specs, false},
        {ExSlop.Check.Refactor.MapIntoLiteral, []},
        {ExSlop.Check.Refactor.IdentityMap, []},
        {ExSlop.Check.Refactor.SortThenReverse, []},
        {ExSlop.Check.Readability.ObviousComment, []},
        {ExSlop.Check.Readability.StepComment, []},
        {ExSlop.Check.Readability.NarratorComment, []}
      ]
    }
  ]
}
