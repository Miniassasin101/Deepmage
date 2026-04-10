## [b]Condition:[/b] RequiresWeaponType
## Passes when the skill's owner has a weapon of [member required_type] equipped
## in any weapon slot (weapon_main, weapon_off, or implement).
##
## Designed for learned skills (not weapon-granted skills) that are weapon-type gated.
## Example: "Sword Mastery" — requires a SWORD equipped somewhere.
##
## Does NOT perform a swap; use [EquipmentContainer.ensure_weapon_type_in_main_hand] for that.
class_name RequiresWeaponType
extends SkillCondition

@export var required_type: Weapon.WeaponType = Weapon.WeaponType.SWORD


func check_condition(skill: Skill, _target: Unit) -> bool:
	var owner: Unit = skill.unit
	if owner == null:
		return false
	if owner.character_sheet == null:
		return false
	var ec: EquipmentContainer = owner.character_sheet.equipment_container
	if ec == null:
		return false
	return ec.has_weapon_of_type(required_type)
