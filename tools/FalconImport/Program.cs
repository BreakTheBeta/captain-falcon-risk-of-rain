using System.Numerics;
using System.Text.Json;
using HSDRaw;
using HSDRaw.Common;
using HSDRaw.Common.Animation;
using HSDRaw.Melee.Pl;
using HSDRaw.Tools;
using HSDRaw.Tools.Melee;
using HSDRaw.GX;
class Vertex { public Vector3 P; public int Parent; public bool Pre, Direct; public (int i, float w)[] W = Array.Empty<(int, float)>(); }
class Program
{
    static List<HSD_JOBJ> bones = new(); static List<int> parents = new(); static Matrix4x4[] world = Array.Empty<Matrix4x4>(), inverse = Array.Empty<Matrix4x4>();
    static Matrix4x4 Mat(HSD_Matrix4x3 m) => new(m.M11, m.M21, m.M31, 0, m.M12, m.M22, m.M32, 0, m.M13, m.M23, m.M33, 0, m.M14, m.M24, m.M34, 1);
    static void Walk(HSD_JOBJ j, int parent) { while (j != null) { int i = bones.Count; bones.Add(j); parents.Add(parent); if (j.Child != null) Walk(j.Child, i); j = j.Next; } }
    static Matrix4x4 Euler(Vector3 r) => Matrix4x4.CreateRotationX(r.X) * Matrix4x4.CreateRotationY(r.Y) * Matrix4x4.CreateRotationZ(r.Z);
    static void Pose(List<FOBJ_Player>[] tracks, float frame)
    {
        for (int i = 0; i < bones.Count; i++)
        {
            var j = bones[i]; var t = new Vector3(j.TX, j.TY, j.TZ); var r = new Vector3(j.RX, j.RY, j.RZ); var s = new Vector3(j.SX, j.SY, j.SZ); if (i < tracks.Length) foreach (var k in tracks[i]) { float v = k.GetValue(frame); switch (k.JointTrackType) { case JointTrackType.HSD_A_J_ROTX: r.X = v; break; case JointTrackType.HSD_A_J_ROTY: r.Y = v; break; case JointTrackType.HSD_A_J_ROTZ: r.Z = v; break; case JointTrackType.HSD_A_J_TRAX: t.X = v; break; case JointTrackType.HSD_A_J_TRAY: t.Y = v; break; case JointTrackType.HSD_A_J_TRAZ: t.Z = v; break; case JointTrackType.HSD_A_J_SCAX: s.X = v; break; case JointTrackType.HSD_A_J_SCAY: s.Y = v; break; case JointTrackType.HSD_A_J_SCAZ: s.Z = v; break; } }
            // Melee ftAnim_8006E054 extracts and clears TransN translation.
            // Gameplay physics already owns world travel; preserve pose rotations/bob.
            if (tracks.Length > 0 && i == 1) t = Vector3.Zero;
            world[i] = Matrix4x4.CreateScale(s) * Euler(r) * Matrix4x4.CreateTranslation(t); if (parents[i] >= 0) world[i] *= world[parents[i]];
        }
    }
    static void Main(string[] args)
    {
        if (args[0] == "--motion") {
            var fighterData = (SBM_FighterData)new HSDRawFile(Path.Combine(args[1], "PlCa.dat")).Roots[0].Data;
            var motionAj = new FighterAJManager(File.ReadAllBytes(Path.Combine(args[1], "PlCaAJ.dat")));
            var curves = new Dictionary<string, object>();
            foreach (var actionName in new[]{"SpecialSStart", "SpecialAirSStart", "SpecialS", "SpecialAirS", "SpecialLw", "SpecialAirLw", "SpecialLwEndAir", "SpecialAirLwEndAir", "SpecialAirLwEnd"}) {
                string symbol = motionAj.GetAnimationSymbols().First(x => x.EndsWith("_"+actionName+"_figatree"));
                var anim = (HSD_FigaTree)new HSDRawFile(motionAj.GetAnimationData(symbol)).Roots[0].Data;
                var tracks = anim.Nodes[1].Tracks.Select(t => new FOBJ_Player(t.TrackType,t.GetKeys())).ToArray();
                float[] Translation(int f) => new[]{JointTrackType.HSD_A_J_TRAY,JointTrackType.HSD_A_J_TRAZ}.Select(kind => tracks.FirstOrDefault(t=>t.JointTrackType==kind)?.GetValue(f) ?? 0).ToArray();
                var points = Enumerable.Range(0,(int)Math.Ceiling(anim.FrameCount)+1).Select(Translation).ToArray();
                curves[actionName] = points;
            }
            File.WriteAllText(args[2],JsonSerializer.Serialize(new {curves, attributes=Convert.ToBase64String(fighterData.Attributes2._s.GetData())}));
            return;
        }
        string input = args[0], output = args[1]; Directory.CreateDirectory(output); var file = new HSDRawFile(Path.Combine(input, "PlCaNr.dat")); var root = (HSD_JOBJ)file.Roots.First(r => r.Data is HSD_JOBJ).Data; Walk(root, -1); if (bones.Count < 2 || bones[1]._s != root.Child._s || parents[1] != 0) throw new Exception("Expected Falcon TransN as root child"); world = new Matrix4x4[bones.Count]; inverse = new Matrix4x4[bones.Count]; Pose(Array.Empty<List<FOBJ_Player>>(), 0); for (int i = 0; i < bones.Count; i++) { Matrix4x4.Invert(world[i], out inverse[i]); if (bones[i].InverseWorldTransform != null) inverse[i] = Mat(bones[i].InverseWorldTransform); }
        var fighter = (SBM_FighterData)new HSDRawFile(Path.Combine(input, "PlCa.dat")).Roots[0].Data; var visibility = fighter.ModelLookupTables.CostumeVisibilityLookups[0]; var hidden = new HashSet<int>(); void SetVis(SBM_LookupTable lut, int which) { if (lut?.LookupEntries == null) return; var entries = lut.LookupEntries.Array; for (int i = 0; i < entries.Length; i++) foreach (byte id in entries[i].Entries) { if (i == which) hidden.Remove(id); else hidden.Add(id); } }
        foreach (var lut in visibility.HighPoly.Array) SetVis(lut, 0); foreach (var lut in visibility.LowPoly.Array) SetVis(lut, -1);
        var textures = new List<object>(); var verts = new List<Vertex>(); var tris = new List<double[]>(); var unique = new Dictionary<string, int>(); int dobjIndex = 0;
        for (int ji = 0; ji < bones.Count; ji++)
        {
            var joint = bones[ji]; if (joint.Dobj == null) continue; foreach (var dobj in joint.Dobj.List)
            {
                int di = dobjIndex++; if (hidden.Contains(di) || dobj.Pobj == null) continue; var mat = dobj.Mobj?.Material; HSD_TOBJ tex = dobj.Mobj?.Textures?.List.FirstOrDefault(x => x.ImageData != null && (int)x.GXTexGenSrc >= 4 && (int)x.GXTexGenSrc <= 11); byte[] pixels = tex?.GetDecodedImageData(); int tw = tex?.ImageData.Width ?? 0, th = tex?.ImageData.Height ?? 0;
                int textureId = 0; if (pixels != null) { textures.Add(new { width = tw, height = th, bgra = Convert.ToBase64String(pixels) }); textureId = textures.Count; }
                foreach (var pobj in dobj.Pobj.List)
                {
                    if (pobj.Attributes == null) continue; var dl = pobj.ToDisplayList(); var ids = new List<int>(); foreach (var v in dl.Vertices)
                    {
                        var x = new Vertex { P = new(v.POS.X, v.POS.Y, v.POS.Z), Parent = ji }; if (dl.Envelopes.Count > 0) { var env = dl.Envelopes[v.PNMTXIDX / 3]; x.W = Enumerable.Range(0, env.EnvelopeCount).Select(i => (bones.FindIndex(j => j._s == env.GetJOBJAt(i)._s), env.GetWeightAt(i))).ToArray(); x.Direct = joint.Flags.HasFlag(JOBJ_FLAG.SKELETON_ROOT) && x.W.Length == 1 && x.W[0].w == 1; x.Pre = !joint.Flags.HasFlag(JOBJ_FLAG.SKELETON_ROOT); } else { var bound = pobj.SingleBoundJOBJ; x.Parent = bound == null ? ji : bones.FindIndex(j => j._s == bound._s); }
                        if (x.Parent < 0 || x.W.Any(w => w.i < 0)) throw new Exception("Unresolved bone"); string key = $"{x.P}/{x.Parent}/{x.Pre}/{x.Direct}/" + string.Join(';', x.W); if (!unique.TryGetValue(key, out int vi)) { vi = verts.Count; verts.Add(x); unique[key] = vi; }
                        ids.Add(vi);
                    }
                    int off = 0; foreach (var prim in dl.Primitives)
                    {
                        void Tri(int a, int b, int c)
                        {
                            var va = dl.Vertices[off + a]; var vb = dl.Vertices[off + b]; var vc = dl.Vertices[off + c]; int rr = mat?.DIF_R ?? 160, gg = mat?.DIF_G ?? 160, bb = mat?.DIF_B ?? 160;
                            if (pixels != null) { float u = (va.TEX0.X + vb.TEX0.X + vc.TEX0.X) / 3, v = (va.TEX0.Y + vb.TEX0.Y + vc.TEX0.Y) / 3; int px = (int)(Math.Clamp(u, 0, .99999f) * tw), py = (int)(Math.Clamp(v, 0, .99999f) * th); int ix = (py * tw + px) * 4; bb = pixels[ix]; gg = pixels[ix + 1]; rr = pixels[ix + 2]; }
                            if (ids[off + a] != ids[off + b] && ids[off + b] != ids[off + c] && ids[off + a] != ids[off + c]) tris.Add(new double[] { ids[off + a] + 1, ids[off + b] + 1, ids[off + c] + 1, (rr << 16) | (gg << 8) | bb, textureId, va.TEX0.X, va.TEX0.Y, vb.TEX0.X, vb.TEX0.Y, vc.TEX0.X, vc.TEX0.Y });
                        }
                        switch (prim.PrimitiveType) { case GXPrimitiveType.Triangles: for (int k = 0; k + 2 < prim.Count; k += 3) Tri(k, k + 1, k + 2); break; case GXPrimitiveType.TriangleStrip: for (int k = 2; k < prim.Count; k++) if (k % 2 == 0) Tri(k - 2, k - 1, k); else Tri(k - 1, k - 2, k); break; case GXPrimitiveType.TriangleFan: for (int k = 2; k < prim.Count; k++) Tri(0, k - 1, k); break; case GXPrimitiveType.Quads: for (int k = 0; k + 3 < prim.Count; k += 4) { Tri(k, k + 1, k + 2); Tri(k, k + 2, k + 3); } break; }
                        off += prim.Count;
                    }
                }
            }
        }
        Console.WriteLine("Mesh extracted; action count=" + fighter.FighterActionTable.Count); foreach (var action in fighter.FighterActionTable.Commands) { if (action.Name != null && action.SubAction != null) {var stem=Path.Combine(output,action.Name.Replace("/","_"));File.WriteAllBytes(stem+".cmd",action.SubAction._s.GetData());var blocks=action.SubAction._s.GetSubStructs();File.WriteAllText(stem+".graph.json",JsonSerializer.Serialize(blocks.Select(b=>new{data=Convert.ToBase64String(b.GetData()),refs=b.References.ToDictionary(k=>k.Key.ToString(),k=>blocks.IndexOf(k.Value))})));} }
        Console.WriteLine("Actions extracted"); var sf = fighter.CommonSoundEffectTable; File.WriteAllText(Path.Combine(output, "common-sounds.json"), JsonSerializer.Serialize(new { jump = sf.SFX_Jump, doublejump = sf.SFX_DoubleJump, dodge = sf.SFX_Dodge, ko = sf.SFX_YouFreakinDied, smash = sf.RandomSmashSFX.Entries }));
        var aj = new FighterAJManager(File.ReadAllBytes(Path.Combine(input, "PlCaAJ.dat"))); var mapping = new Dictionary<string, string> { { "idle", "Wait1" }, { "run", "Run" }, { "walk", "WalkMiddle" }, { "jump", "JumpF" }, { "doublejump", "JumpAerialF" }, { "fall", "Fall" }, { "jab1", "Attack11" }, { "jab2", "Attack12" }, { "gentleman", "Attack13" }, { "ftilt", "AttackS3S" }, { "utilt", "AttackHi3" }, { "dtilt", "AttackLw3" }, { "dashattack", "AttackDash" }, { "fsmash", "AttackS4S" }, { "usmash", "AttackHi4" }, { "dsmash", "AttackLw4" }, { "nair", "AttackAirN" }, { "knee", "AttackAirF" }, { "bair", "AttackAirB" }, { "uair", "AttackAirHi" }, { "dair", "AttackAirLw" }, { "punch", "SpecialN" }, { "airpunch", "SpecialAirN" }, { "raptor", "SpecialSStart" }, { "raptorhit", "SpecialS" }, { "airraptor", "SpecialAirSStart" }, { "airraptorhit", "SpecialAirS" }, { "kickrecovery", "SpecialLwEndAir" }, { "airkickrecovery", "SpecialAirLwEndAir" }, { "dive", "SpecialHi" }, { "kick", "SpecialLw" }, { "airkick", "SpecialAirLw" }, { "airdodge", "EscapeAir" }, { "roll", "EscapeF" }, { "spotdodge", "EscapeN" }, { "shield", "Guard" }, { "taunt", "AppealR" }, { "landing", "Landing" }, { "death", "DamageFlyTop" } };
        File.WriteAllText(Path.Combine(output, "skeleton.json"), JsonSerializer.Serialize(bones.Select((j,i)=>new {index=i,parent=parents[i],tx=j.TX,ty=j.TY,tz=j.TZ})));
        var clips = new Dictionary<string, object>(); foreach (var (name, action) in mapping) { string symbol = aj.GetAnimationSymbols().FirstOrDefault(x => x.EndsWith("_" + action + "_figatree")); if (symbol == null) throw new Exception("Missing " + action); var af = new HSDRawFile(aj.GetAnimationData(symbol)); var anim = (HSD_FigaTree)af.Roots[0].Data; var tracks = anim.Nodes.Select(n => n.Tracks.Select(t => new FOBJ_Player(t.TrackType, t.GetKeys())).ToList()).ToArray(); int frames = (int)Math.Ceiling(anim.FrameCount); using var bw = new BinaryWriter(File.Create(Path.Combine(output, name + ".bin"))); for (int frame = 0; frame < frames; frame++) { Pose(tracks, frame); foreach (var v in verts) { Vector3 p = v.P; if (v.W.Length == 0) p = Vector3.Transform(p, world[v.Parent]); else if (v.Direct) p = Vector3.Transform(p, world[v.W[0].i]); else { if (v.Pre) p = Vector3.Transform(p, world[v.Parent]); Vector3 skinned = Vector3.Zero; foreach (var (bi, w) in v.W) skinned += Vector3.Transform(p, inverse[bi] * world[bi]) * w; p = skinned; } bw.Write(p.X); bw.Write(p.Y); bw.Write(p.Z); } } clips[name] = new { frames, symbol }; Console.WriteLine($"{name}: {frames} frames"); }
        File.WriteAllText(Path.Combine(output, "mesh.json"), JsonSerializer.Serialize(new { vertices = verts.Count, triangles = tris, textures, bones = bones.Count, rootMotion = "TransN translation removed; gameplay physics owns travel", clips })); Console.WriteLine($"{verts.Count} vertices, {tris.Count} triangles, {bones.Count} joints");
    }
}
