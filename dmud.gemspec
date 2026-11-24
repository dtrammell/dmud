Gem::Specification.new do |spec|
	spec.name          = 'dmud'
	spec.version       = '0.0.1'
	spec.authors       = ['Dustin Trammell']
	spec.email         = ['dtrammell@dustintrammell.com']
	spec.summary       = 'Distributed Multi-User Dungeon engine'
	spec.description   = 'DMUD is a Ruby world-building engine for composing MUD-style game worlds.'
	spec.homepage      = 'https://github.com/dtrammell/dmud'
	spec.license       = 'MIT'
	spec.required_ruby_version = '>= 3.3'

	spec.files         = Dir['lib/**/*.rb'] + %w[LICENSE README.md docs/ARCHITECTURE.md docs/KNOWN_ISSUES.md]
	spec.require_paths = ['lib']

	spec.add_runtime_dependency     'reline', '~> 0.5'
	spec.add_development_dependency 'minitest', '~> 5.0'
	spec.add_development_dependency 'rake', '~> 13.0'
end
