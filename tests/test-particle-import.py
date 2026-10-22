import json,os,struct,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from melee_particles import emitter_events,Scene

class ParticleImportTests(unittest.TestCase):
 def test_multiple_timed_particle_keys(self):
  def value(id):return struct.pack('<I',id*64+4)
  data=b'\x16'+value(42)+b'\x03'+value(43)+b'\x00\x00'
  self.assertEqual(emitter_events({'buffer':data.hex(),'start':-50}),[(50,4,42),(53,4,43)])
 def test_unknown_animation_opcode_is_rejected(self):
  with self.assertRaises(ValueError):emitter_events({'buffer':'01','start':0})
 def test_imported_particles_have_native_timing(self):
  root=Path(os.environ['FALCON_MOD_ROOT']);audit=json.loads((root/'melee-effect-audit.json').read_text())
  self.assertEqual(audit['models']['effect0']['first_visible'],50)
  self.assertEqual(audit['models']['effect2']['first_visible'],14)
  self.assertEqual(len(audit['archive_sha256']),64)
 def test_atlases_contain_visible_original_pixels(self):
  from PIL import Image
  root=Path(os.environ['FALCON_MOD_ROOT']);audit=json.loads((root/'melee-effect-audit.json').read_text())
  for name,entry in audit['models'].items():
   image=Image.open(root/'assets/melee-effects'/f'{name}.png')
   self.assertEqual(image.size,(entry['width']*entry['frames'],entry['height']))
   self.assertIsNotNone(image.getbbox())
   if entry['first_visible']:
    self.assertIsNone(image.crop((0,0,entry['width']*entry['first_visible'],entry['height'])).getbbox())
if __name__=='__main__':unittest.main()
