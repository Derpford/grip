version "4.10"

class GripHandle : EventHandler {
    // GOTTA GET A GRIP!!
    // There are 3 stages involved in getting a grip.
    // 1. Normality. Nothing is glowing or flashing or anything. 
    // Upon killing something...
    // 2. Pretty colors! Things that die start spitting rainbows everywhere.
    // Chance of this happening increases with each kill.
    // 3. I don't feel so good... ***Everything*** starts turning rainbowy.
    // Once you've reached 100% rainbow chance, things that spawn will start with perma-rainbows, and each kill is followed by something else getting perma-rainbowed.
    // [insert Death Grips reference here for secret 4th stage or something]

    int combo; // How many kills have you chained together? Chaining at least 5 combos together temporarily increases your Grip level.
    double timer; // How long until the kill chain wears off?
    double timermax;
    double progress; // Gains 0.05 per monster kill, 0.025 per object kill. Above 0, increase grip stage to 2. At 1, increases grip stage to 3.

    int GetGripStage() {
        int grip = 1;
        if (progress >= 0.01 && progress < 1) {
            grip = 2;
        }
        if (progress >= 1) {
            grip = 3;
        }

        if (timer > 0 && combo > 5) {
            grip = grip + 1;
        }

        return clamp(grip,1,3);
    }

    override void OnRegister() {
        combo = 0;
        timer = 0.0;
        timermax = 3.0;
        progress = 0.0;
    }

    override void WorldLoaded() {
        progress = 0.0;
        combo = 0;
        timer = 0.0;
    }

    void AddCombo() {
        combo += 1;
        timer = timermax;
    }

    double GetProgress() {
        return progress;
    }

    override void WorldTick() {
        if (timer >= 0) {
            timer -= 1./35.;
        } else {
            combo = 0;
        }
    }

    override void WorldThingDamaged(WorldEvent e) {
        if (e.Thing.health - e.Damage <= 0) {
            // The thing will die because of this damage! Probably.
            if (GetGripStage() > 2 || frandom(0,1) <= progress) {
                e.Thing.GiveInventory("Grip",1);
            }

            if (e.Thing.bISMONSTER) {
                AddCombo();
                progress = min(1,progress+0.05);
            } else {
                progress += min(1,progress+0.025);
            }
        }    
    }

    override void WorldThingDied(WorldEvent e) {
        if (GetGripStage() > 2) {
            ThinkerIterator it = ThinkerIterator.create("Actor");
            Actor mo;
            while (mo = Actor(it.next())) {
                if (mo.CountInv("Grip") < 0) {
                    mo.GiveInventory("Grip",1);
                    break;
                }
            }
        }
    }

    override void WorldThingSpawned(WorldEvent e) {
        if (!(e.Thing is "Grip")) {
            if (frandom(0,2) <= progress || GetGripStage() > 2) {
                e.Thing.GiveInventory("Grip",1);
            }
        }
    }
}

class Grip : Inventory {
    double time; // How long do we have a grip?
    bool init; // Have we finished init?
    bool dead; // Is our owner dead?
    bool emitted; // Have we done a particle?
    double progress;
    double coloffset; // Add this to GetAge() for some randomness.
    FSpawnParticleParams silhouette;

    default {
        Inventory.MaxAmount 1;
    }

    void InitTimer() {
        time = 30. * progress;
    }

    override void PostBeginPlay() {
        silhouette.style = STYLE_Stencil;
        silhouette.flags = SPF_FULLBRIGHT|SPF_NOTIMEFREEZE|SPF_ROLL|SPF_REPLACE|SPF_NO_XY_BILLBOARD;
        silhouette.lifetime = 35;
        silhouette.startalpha = 1;
        // silhouette.size = ;
        silhouette.fadestep = 0;
        silhouette.rollvel = frandom(-4,4);
        coloffset = frandom(0,360);
    }

    Color GetColor() {
        // HSV:
        double hue = (GetAge() + coloffset) % 360;
        // saturation and value are always maxed
        double sat = 1;
        double val = 1;
        vector3 rgb;

        double c = sat * val;
        double x = c * (1 - abs(((hue/60) % 2) - 1));
        double m = val - c;
        // Time for a big ifchain. Augh.
        if (hue >= 0 && hue < 60) {
            rgb.x = c;
            rgb.y = x;
            rgb.z = 0;
        } else if (hue >= 60 && hue < 120) {
            rgb.x = x;
            rgb.y = c;
            rgb.z = 0;
        } else if(hue >= 120 && hue < 180) {
            rgb.x = 0;rgb.y = C;rgb.z = X;
        } else if(hue >= 180 && hue < 240) {
            rgb.x = 0;rgb.y = X;rgb.z = C;
        } else if(hue >= 240 && hue < 300) {
            rgb.x = X;rgb.y = 0;rgb.z = C;
        } else {
            rgb.x = C;rgb.y = 0;rgb.z = X;
        }

        int r = 255 * rgb.x;
        int g = 255 * rgb.y;
        int b = 255 * rgb.z;
        int a = 255;
        return Color(a,r,g,b);
    }

    override void Tick() {
        Super.Tick();

        let handle = GripHandle(EventHandler.Find("GripHandle"));
        progress = handle.progress;

        if (!init) {
            InitTimer();
            init = true;
        }

        if (!dead && owner && owner.health <= 0) {
            InitTimer();
            dead = true;
        }

        if (time >= 0) {
            time -= 1./35.;
            if (owner && GetAge() % 5 == 0) {
                Actor cam = players[consoleplayer].mo;
                double AngToCam = owner.AngleTo(cam);
                silhouette.pos = owner.Vec3Angle(owner.radius,AngToCam+180,owner.height/2);
                silhouette.vel = -owner.Vec3To(cam).unit();
                silhouette.texture = owner.curstate.GetSpriteTexture(0);
                silhouette.color1 = GetColor(); // TODO: Color cycling
                int xs, ys;
                [xs,ys] = TexMan.GetSize(silhouette.texture);
                silhouette.size = max(xs * owner.scale.x,ys * owner.scale.y);
                silhouette.startroll = owner.roll+180;
                silhouette.sizestep = -(silhouette.size * 1./35.);
                LevelLocals.SpawnParticle(silhouette);
                // emitted = true;
            }
        }
    }
}