{
	setDefaultEnv = name: default:
		''
						if [ -z "${name}" ]; then
							export ${name}="${default}"
							echo "⚠️  [WARN] Default used for ${name} = ${default}"
						else
							echo "ℹ️  [INFO] ${name} set to $'' + "${name}" + ''"
						fi
		'';

	requireEnv = name: ''
						if [ -z "${name}" ]; then
							echo "❌ [ERROR] Required env ${name} is missing"
							exit 1
						else
							echo "✅ [OK] Required env ${name} set to $'' + "${name}" + ''"
						fi
		'';
}
