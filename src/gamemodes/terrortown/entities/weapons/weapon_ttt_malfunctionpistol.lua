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

-- Same ammo type as the flare-gun.
SWEP.Primary.Ammo = "AR2AltFire"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID = AMMO_MALFUNCTIONGUN

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
	bullet.Spread     = Vector( cone, cone, 0 )
	bullet.Tracer     = 1
	bullet.Force      = 2
	bullet.Damage     = self.Primary.Damage
	bullet.TracerName = self.Tracer
	bullet.Callback   = ForceTargetToShoot

	self.Owner:FireBullets(bullet)
end

function ForceTargetToShoot(ply, path, dmginfo)
	local ent = path.Entity
	if not IsValid(ent) then return end

	if CLIENT and IsFirstTimePredicted() then
		if ent:GetClass() == "prop_ragdoll" then
			ScorchUnderRagdoll(ent)
		end
		return
	end

	if SERVER then
		-- disallow if prep or post round
		if (not ent:IsPlayer()) or (not GAMEMODE:AllowPVP()) then
			return
		end

		local repeats
		local clipsize = ent:GetActiveWeapon().Primary.ClipSize

		if clipsize < 0 then
			local weapons = ent:GetWeapons()
			local preferredWeapons = {}

			for weapon in weapons do
				local class = weapon:GetClass()
				local wswep = util.WeaponForClass(class)

				-- Filter out grenades & magNEATo-stick & holster
				if wswep then
					local slot = wswep.Slot
					if (slot ~= 3) and (slot ~= 4) and (slot ~= 5) then
						table.insert(preferredWeapons, class)
					end
				end
			end

			if #preferredWeapons > 0 then
				ent:SelectWeapon(table.Random(preferredWeapons))
				-- Selected a new weapon so we need to get the new ClipSize.
				clipsize = ent:GetActiveWeapon().Primary.ClipSize
			else
				-- Pull out the crowbar.
				ent:SelectWeapon("weapon_zm_improvised")
				repeats = 6
			end
		end

		if repeats == nil then
			local range = clipsize * 0.05
			repeats = (clipsize / 2) + math.random(-range, range)
		end

		ent.malfunctionInfluencer = ply
		timer.Create("influenceDisable", ent:GetActiveWeapon().Primary.Delay*repeats+0.1, 1,
		function()
			ent.malfunctionInfluencer = nil
		end)

		timer.Create("burstFire", ent:GetActiveWeapon().Primary.Delay, repeats,
		function()
			ent:GetActiveWeapon():PrimaryAttack()
		end)
	end
end

hook.Add("EntityTakeDamage", "PreventsWrongDamageLogs", function(target, dmg)
	local influencer = dmg:GetAttacker().malfunctionInfluencer
	if IsValid(influencer) then
		dmg:SetAttacker(influencer)
	end
end)
