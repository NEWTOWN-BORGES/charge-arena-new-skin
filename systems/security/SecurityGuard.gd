extends RefCounted
## SecurityGuard: Camada de Proteção, Criptografia e Integridade Anti-Tamper / Anti-Mods
##
## Protege contra:
## 1. Clonagem de APK e alteração de package name
## 2. Injeção de mods e edição arbitrária de saves (user://*.cfg)
## 3. Depuração não autorizada e engenharia reversa em produção
## 4. Manipulação de regras de combate e economia de tijolos

const SECRET_SALT = "CA_SEC_v3_98a7f14b3c2e5d6a890f123456789abc"

# Pacotes oficiais autorizados
const AUTHORIZED_PACKAGES = [
	"org.chargearena.game",
	"org.chargearena.teste",
	"org.chargearena.playtest",
	"org.chargearena.newskinlab"
]

# Gera hash SHA-256 seguro para proteger dados contra edição externa
static func generate_hash(payload: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var raw = (payload + ":" + SECRET_SALT).to_utf8_buffer()
	ctx.update(raw)
	var digest = ctx.finish()
	return digest.hex_encode()

# Valida se o hash armazenado confere com o conteúdo do arquivo
static func verify_hash(payload: String, expected_hash: String) -> bool:
	if expected_hash.is_empty():
		return false
	return generate_hash(payload) == expected_hash

# Assina um arquivo ConfigFile antes de salvar
static func sign_config(config: ConfigFile, section: String = "data") -> void:
	var buffer: PackedStringArray = []
	for key in config.get_section_keys(section):
		buffer.append("%s=%s" % [key, str(config.get_value(section, key))])
	buffer.sort()
	var payload = ";".join(buffer)
	config.set_value("_security", "signature", generate_hash(payload))

# Valida a assinatura de um ConfigFile ao carregar
static func verify_config(config: ConfigFile, section: String = "data") -> bool:
	if not config.has_section("_security") or not config.has_section_key("_security", "signature"):
		return false
	var saved_sig = String(config.get_value("_security", "signature", ""))
	var buffer: PackedStringArray = []
	for key in config.get_section_keys(section):
		buffer.append("%s=%s" % [key, str(config.get_value(section, key))])
	buffer.sort()
	var payload = ";".join(buffer)
	return verify_hash(payload, saved_sig)

# Verifica se o APK foi clonado com outro Package Name
static func verify_package_integrity(package_name: String) -> bool:
	if package_name.is_empty():
		return true # Em ambiente de desenvolvimento/editor
	return AUTHORIZED_PACKAGES.has(package_name)

# Checa se o ambiente de execução é seguro para produção
static func is_environment_safe() -> bool:
	# Em builds de loja/produção, impede execução se estiver com depurador ativo
	if OS.has_feature("store_galaxy") or OS.has_feature("store_google"):
		if OS.is_debug_build():
			return false
	return true

