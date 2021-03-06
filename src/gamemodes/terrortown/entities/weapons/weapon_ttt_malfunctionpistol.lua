AddCSLuaFile()

SWEP.HoldType = "pistol"

if CLIENT then
	SWEP.PrintName = "Malfunction Pistol"
	SWEP.Slot = 6

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "Forces the player you shoot to fire\na uncontrolled round of shots."
	}

	SWEP.Icon = "vgui/ttt/icon_malfunction"
	SWEP.IconLetter = "a"
end

SWEP.Base = "weapon_tttbase"
SWEP.Primary.Recoil      = 1.35
SWEP.Primary.Damage      = 0
SWEP.Primary.Delay       = 0.38
SWEP.Primary.Cone        = 0.02
SWEP.Primary.ClipSize    = 3
SWEP.Primary.Automatic   = true
SWEP.Primary.DefaultClip = 3
SWEP.Primary.ClipMax     = 3

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR} -- only traitors can buy
SWEP.LimitedStock = true -- only buyable once

SWEP.IsSilent = true

SWEP.UseHands      = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV  = 54
SWEP.ViewModel  = "models/weapons/cstrike/c_pist_fiveseven.mdl"
SWEP.WorldModel = "models/weapons/w_pist_fiveseven.mdl"

SWEP.Primary.Sound = Sound("weapons/usp/usp1.wav")
SWEP.Primary.SoundLevel = 50

SWEP.IronSightsPos = Vector(-5.91, -4, 2.84)
SWEP.IronSightsAng = Vector(-0.5, 0, 0)

SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim = ACT_VM_RELOAD_SILENCED

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW_SILENCED)
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	if GetRoundState() ~= ROUND_ACTIVE then return end

	if not self:CanPrimaryAttack() then return end

	self:EmitSound(self.Primary.Sound)

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	self:ShootMalfunctionBullet()

	self:TakePrimaryAmmo(1)

	if IsValid(self.Owner) then
		self.Owner:SetAnimation(PLAYER_ATTACK1)

		self.Owner:ViewPunch(Angle( math.Rand(-0.2, -0.1) * self.Primary.Recoil, math.Rand(-0.1, 0.1) * self.Primary.Recoil, 0 ))
	end

	if CLIENT or game.SinglePlayer() then
		self:SetNetworkedFloat("LastShootTime", CurTime())
	end
end

function SWEP:ShootMalfunctionBullet()
	local cone = self.Primary.Cone
	local bullet = {}

	bullet.Num        = 1
	bullet.Src        = self.Owner:GetShootPos()
	bullet.Dir        = self.Owner:GetAimVector()
	bullet.Spread     = Vector(cone, cone, 0)
	bullet.Tracer     = 1
	bullet.Force      = 2
	bullet.Damage     = self.Primary.Damage
	bullet.TracerName = self.Tracer
	bullet.Callback   = ForceTargetToShoot

	self.Owner:FireBullets(bullet)
end

function ForceTargetToShoot(plr, path, dmg)
	local tgt = path.Entity
	if not IsValid(tgt) then return end

	if CLIENT and IsFirstTimePredicted() then
		if tgt:GetClass() == "prop_ragdoll" then
			ScorchUnderRagdoll(tgt)
		end
		return
	end

	if SERVER and tgt:IsPlayer() then
		local repeats
		local clipsize = tgt:GetActiveWeapon().Primary.ClipSize

		if clipsize < 1 then
			local weapons = tgt:GetWeapons()
			local preferredWeapons = {}

			for _, weapon in pairs(weapons) do
				local class = weapon:GetClass()

				if weapon.Primary.ClipSize > 0 then
					local kind = WEPS.TypeForWeapon(class)
					-- Filter out grenades & magNEATo-stick & holster
					if (kind ~= WEAPON_NONE) and (kind ~= WEAPON_UNARMED) and
							(kind ~= WEAPON_NADE) and (kind ~= WEAPON_CARRY) then
						table.insert(preferredWeapons, class)
					end
				end
			end

			if #preferredWeapons > 0 then
				tgt:SelectWeapon(table.Random(preferredWeapons))
				-- Selected a new weapon so we need to get the new ClipSize.
				clipsize = tgt:GetActiveWeapon().Primary.ClipSize
			else
				-- Pull out the crowbar.
				tgt:SelectWeapon("weapon_zm_improvised")
				repeats = 6
			end
		end

		if repeats == nil then
			local range = clipsize * 0.05
			repeats = (clipsize / 2) + math.random(-range, range)
		end

		tgt.malfunctionInfluencer = plr
		local delay = tgt:GetActiveWeapon().Primary.Delay

		timer.Create("influenceDisable", (delay * repeats) + 0.1, 1, function()
			tgt.malfunctionInfluencer = nil
		end)

		timer.Create("burstFire", delay, repeats, function()
			tgt:GetActiveWeapon():PrimaryAttack()
		end)
	end
end

if SERVER then
	-- HOOK_HIGH can be used if ULib is present. Otherwise it's nil which is fine.
	-- This is done so other hooks don't receive the wrong attacker.
	hook.Add("EntityTakeDamage", "SetMalfunctionAttacker", function(tgt, dmg)
		local influencer = dmg:GetAttacker().malfunctionInfluencer
		if IsValid(influencer) then
			dmg:SetAttacker(influencer)
		end
	end, HOOK_HIGH)

	hook.Add("PlayerSwitchWeapon", "PreventSwitchDuringMalfunction", function(plr)
		local influencer = plr.malfunctionInfluencer
		if IsValid(influencer) then
			return true -- Prevents weapon switch.
		end
	end)
end
