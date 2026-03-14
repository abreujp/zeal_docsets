%Doctor.Config{
  ignore_modules: [Mix.Tasks.Zeal.Docs, ZealDocsets.Fixtures],
  ignore_paths: ["test/support"],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 90,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 0,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Summary,
  struct_type_spec_required: true,
  umbrella: false
}
