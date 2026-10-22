using System.Text.Json;
using System.Numerics;
using HSDRaw.Common.Animation;
using HSDRaw.Tools;
using HSDRaw;
using HSDRaw.Common;
using HSDRaw.Melee.Ef;

static class EffectImport
{
    static object[] Emitters(SBM_EffectModel model)
    {
        var joints=new List<HSD_JOBJ>();var parents=new List<int>();var tracks=new List<FOBJ_Player[]>();var descs=new List<HSD_FOBJDesc[]>();
        void Walk(HSD_JOBJ j,HSD_AnimJoint a,int parent) {
            while(j!=null) {
                int index=joints.Count;joints.Add(j);parents.Add(parent);
                var ds=a?.AOBJ?.FObjDesc?.List.ToArray() ?? Array.Empty<HSD_FOBJDesc>();descs.Add(ds);tracks.Add(ds.Select(f=>new FOBJ_Player(f)).ToArray());
                if(j.Child!=null)Walk(j.Child,a?.Child,index);
                j=j.Next;a=a?.Next;
            }
        }
        Walk(model.RootJoint,model.JointAnim,-1);
        var frames=new List<float[]>[joints.Count];for(int i=0;i<frames.Length;i++)frames[i]=new();
        for(int frame=0;frame<Math.Ceiling(model.FrameCount);frame++) {
            var world=new Matrix4x4[joints.Count];
            for(int i=0;i<joints.Count;i++) {
                var j=joints[i];var t=new Vector3(j.TX,j.TY,j.TZ);var r=new Vector3(j.RX,j.RY,j.RZ);var scale=new Vector3(j.SX,j.SY,j.SZ);
                for(int ki=0;ki<tracks[i].Length;ki++) { var k=tracks[i][ki];
                    float v=k.JointTrackType==JointTrackType.HSD_A_J_PTCL ? 0 : k.GetValue(frame+descs[i][ki].StartFrame);
                    switch(k.JointTrackType) {
                    case JointTrackType.HSD_A_J_TRAX:t.X=v;break;case JointTrackType.HSD_A_J_TRAY:t.Y=v;break;case JointTrackType.HSD_A_J_TRAZ:t.Z=v;break;
                    case JointTrackType.HSD_A_J_ROTX:r.X=v;break;case JointTrackType.HSD_A_J_ROTY:r.Y=v;break;case JointTrackType.HSD_A_J_ROTZ:r.Z=v;break;
                    case JointTrackType.HSD_A_J_SCAX:scale.X=v;break;case JointTrackType.HSD_A_J_SCAY:scale.Y=v;break;case JointTrackType.HSD_A_J_SCAZ:scale.Z=v;break;
                    }
                }
                if(parents[i]<0)t=Vector3.Zero;
                world[i]=Matrix4x4.CreateScale(scale)*Matrix4x4.CreateRotationX(r.X)*Matrix4x4.CreateRotationY(r.Y)*Matrix4x4.CreateRotationZ(r.Z)*Matrix4x4.CreateTranslation(t);
                if(parents[i]>=0)world[i]*=world[parents[i]];
                var m=world[i];frames[i].Add(new[]{m.M11,m.M12,m.M13,m.M21,m.M22,m.M23,m.M31,m.M32,m.M33,m.M41,m.M42,m.M43});
            }
        }
        var result=new List<object>();
        for(int i=0;i<joints.Count;i++)foreach(var d in descs[i].Where(t=>t.JointTrackType==JointTrackType.HSD_A_J_PTCL)) { var t=new FOBJ_Player(d);result.Add(new {joint=i,bank=t.PtclBank,id=t.PtclId,start=d.StartFrame,buffer=Convert.ToHexString(d.Buffer),matrices=frames[i]}); }
        return result.ToArray();
    }
    public static void Export(string input, string output)
    {
        Directory.CreateDirectory(output);
        var file = new HSDRawFile(Path.Combine(input, "EfCaData.dat"));
        foreach (var r in file.Roots) Console.WriteLine($"Effect root: {r.Name} ({r.Data.GetType().Name})");
        var table = (SBM_EffectTable)file.Roots.First(r => r.Name == "effCaptainDataTable").Data;
        var fighter=(HSDRaw.Melee.Pl.SBM_FighterData)new HSDRawFile(Path.Combine(input,"PlCa.dat")).Roots[0].Data;
        int ReadFoot(bool left)=>left ? fighter.ModelLookupTables.LeftFootBone : fighter.ModelLookupTables.RightFootBone;
        var textures = table.TextureGraphics.ParticleImages.Select((t,i) => new {index=i,width=t.Width,height=t.Height,images=t.GetRGBAImageData().Select(Convert.ToBase64String)}).ToArray();
        var generators = table.Particles.Generators.Select((g,i) => new {index=i,texture=g.TexGroup,shape=(int)g.TypeShape,flags=(int)g.Flags,kind=(uint)g.Kind,life=g.Life,genLife=g.GenLife,gravity=g.Gravity,friction=g.Friction,vx=g.VX,vy=g.VY,vz=g.VZ,radius=g.Radius,angle=g.Angle,random=g.Random,size=g.Size,param1=g.Param1,param2=g.Param2,param3=g.Param3,commands=Convert.ToBase64String(g.TrackData)}).ToArray();
        object Joint(HSD_JOBJ j) => new {flags=(uint)j.Flags,tx=j.TX,ty=j.TY,tz=j.TZ,rx=j.RX,ry=j.RY,rz=j.RZ,sx=j.SX,sy=j.SY,sz=j.SZ,particle=j.ParticleJoint is {} p ? new {id=p.ParticleID,bank=p.ParticleBank} : null,children=j.Child?.List.Select(Joint).ToArray() ?? Array.Empty<object>()};
        var models=table.Models.Select((m,i)=>new {index=i,frames=m.FrameCount,emitters=Emitters(m),joint=m.RootJoint is {} j ? Joint(j) : null}).ToArray();
        File.WriteAllText(Path.Combine(output,"effects.json"),JsonSerializer.Serialize(new {start=table.Particles.EffectIDStart,anchors=new {leftFoot=ReadFoot(true),rightFoot=ReadFoot(false)},textures,generators,models}));
        Console.WriteLine($"Exported {textures.Length} particle texture groups, {generators.Length} generators and {models.Length} effect models");
    }
}
