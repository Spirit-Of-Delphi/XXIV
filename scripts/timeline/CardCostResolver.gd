class_name CardCostResolver
extends RefCounted

## The single source of truth for how many frames a card occupies and which step frames it uses.
## Future cost modifiers (relics, statuses) get added here and nowhere else.

static func resolve(p_card: CardData, p_tier: Types.SpeedTier, p_config: CombatConfig) -> int:
	var cost: int = p_card.frame_cost
	if p_card.family == Types.CardFamily.MOTION and p_tier >= Types.SpeedTier.TIER_3:
		cost -= p_config.tier_3_motion_cost_reduction
	return maxi(p_config.minimum_card_cost, cost)


static func resolve_step_frames(p_card: CardData, p_tier: Types.SpeedTier) -> Array[int]:
	if p_card.family == Types.CardFamily.MOTION and p_tier >= Types.SpeedTier.TIER_3:
		if not p_card.tier_3_step_frames.is_empty():
			return p_card.tier_3_step_frames.duplicate()
	return p_card.step_frames.duplicate()
