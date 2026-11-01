"""Exercise the production mobile focus/keyboard methods without a GPU/world.

The window records IME requests. Only cfg!(target_os="ios") is parameterized
so the iOS policy can run on CI hosts; actual iOS compilation is a separate check.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def method(source, name):
    start = source.index('fn ' + name + '(')
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


def program(pad_source=None):
    pad_source = pad_source or (ROOT / 'crates/horizon-client/src/game/pad_menu.rs').read_text()
    ime = (ROOT / 'crates/horizon-client/src/game/ime.rs').read_text()
    names = ['pad_typing', 'field_focused', 'sync_system_keyboard', 'show_system_keyboard',
             'hide_system_keyboard', 'toggle_system_keyboard', 'system_keyboard_up', 'pad_osk_output']
    methods = '\n'.join(method(pad_source, n) for n in names)
    assert methods.count('cfg!(target_os = "ios")') == 1
    methods = methods.replace('cfg!(target_os = "ios")', 'self.ios')
    methods += '\n' + method(ime, 'text_field_focused') + '\n' + method(ime, 'ime_commit')
    return STUBS + '\nmod production { use super::*; use books::BookScreen; impl Game {\n' + methods + '\n}\n' + CASES + '\n}\n'


STUBS = r'''
#![allow(dead_code)]
use std::cell::RefCell;
#[macro_export] macro_rules! warn { ($($arg:tt)*) => {{ let _ = format_args!($($arg)*); }}; }
mod log { pub(crate) use crate::warn; }
mod preedit { pub fn set_preedit(_: Option<()>) {} }
mod books { pub enum BookScreen { Edit {}, View } }
mod osk { pub enum Output { Text(String), Backspace, Enter, Close } }
#[derive(Default, PartialEq)] enum Screen { #[default] Playing, Chat, CommandBlock, WorldOptions, Creative, Inventory, Options }
#[derive(Clone, Copy, PartialEq)] enum KeyCode { Backspace, Enter }
#[derive(Default)] struct Window { requests: RefCell<Vec<bool>> }
impl Window { fn set_ime_allowed(&self, value: bool) { self.requests.borrow_mut().push(value); } }
#[derive(Default)] struct Menu { osk: Option<()>, system_keyboard: bool, system_keyboard_hidden: bool, osk_dismissed: bool }
#[derive(Default)] struct Pad { menu: Menu }
struct Title { focused: bool }
impl Title { fn focused_field(&mut self) -> Option<()> { self.focused.then_some(()) } fn confirm_edit(&mut self) {} }
#[derive(Default)] struct Creative { search: bool }
impl Creative { fn tab(&self) -> &Self { self } }
#[derive(Default)] struct Options { typing: bool }
impl Options { fn typing(&self) -> bool { self.typing } fn type_text(&mut self, _: &(), _: &str) {} }
#[derive(Default)] struct Ui { options: Options }
#[derive(Default)] struct Gui { atlas: () }
#[derive(Default)] struct Game {
 ios: bool, screen: Screen, title: Option<Title>, sign_edit: Option<()>, book: Option<books::BookScreen>,
 creative_screen: Creative, pad: Pad, window: Option<Window>, ui: Ui, gui: Gui,
 dialog: bool, dialog_text: bool, recipe: bool, station: bool, command: String, submitted: bool,
}
impl Game {
 fn new() -> Self { Self { ios: true, window: Some(Window::default()), ..Self::default() } }
 fn requests(&self) -> Vec<bool> { self.window.as_ref().unwrap().requests.borrow().clone() }
 fn dialog_open(&self)->bool{self.dialog} fn dialog_text_focused(&self)->bool{self.dialog && self.dialog_text}
 fn dialog_has_text_field(&self)->bool{self.dialog_text} fn recipe_search_focused(&self)->bool{self.recipe}
 fn station_typing(&self)->bool{self.station} fn mod_browser_typing(&self)->bool{false}
 fn world_options_typing(&self)->bool{false} fn mod_browser_text(&mut self,_:Option<&str>,_:bool){}
 fn command_block_type(&mut self,t:&str){self.command.push_str(t)}
 fn command_block_key_code(&mut self,k:KeyCode,_:Option<()>,_:Option<&str>){match k {KeyCode::Backspace=>{self.command.pop();},KeyCode::Enter=>{self.submitted=true;self.screen=Screen::Playing;}}}
 fn dialog_key(&mut self,_:KeyCode,_:Option<()>,_:Option<&str>){} fn dialog_type(&mut self,_:&str)->bool{false}
 fn chat_type(&mut self,_:&str){} fn chat_key_code(&mut self,_:KeyCode,_:Option<()>){}
 fn sign_input(&mut self,_:Option<KeyCode>,_:Option<&str>){} fn book_input(&mut self,_:Option<KeyCode>,_:Option<&str>){}
 fn creative_search_backspace(&mut self,_:bool){} fn creative_search_edit(&mut self,_:Option<&str>){}
 fn recipe_text(&mut self,_:Option<&str>,_:bool){} fn station_text(&mut self,_:Option<&str>,_:bool){}
 fn world_options_text(&mut self,_:Option<&str>){} fn title_edit(&mut self,_:Option<&str>,_:bool){}
 fn options_key(&mut self,_:KeyCode,_:Option<()>)->Result<(),String>{Ok(())}
}
'''

CASES = r'''
#[test] fn command_editor_requests_keyboard_and_receives_ime_text() {
 let mut g=Game::new(); g.screen=Screen::CommandBlock;
 assert!(g.field_focused()); assert!(g.text_field_focused());
 g.sync_system_keyboard(); assert!(g.system_keyboard_up()); assert_eq!(g.requests(),vec![true]);
 g.ime_commit("say mobile"); assert_eq!(g.command,"say mobile");
 g.sync_system_keyboard(); assert_eq!(g.requests(),vec![true],"stable focus must not repeat requests");
}
#[test] fn dismissed_keyboard_stays_hidden_until_reopened_or_focus_changes() {
 let mut g=Game::new(); g.screen=Screen::CommandBlock; g.sync_system_keyboard();
 g.toggle_system_keyboard(); g.sync_system_keyboard();
 assert!(!g.system_keyboard_up()); assert_eq!(g.requests(),vec![true,false]);
 g.sync_system_keyboard(); assert_eq!(g.requests(),vec![true,false]);
 g.toggle_system_keyboard(); assert!(g.system_keyboard_up()); assert_eq!(g.requests(),vec![true,false,false,true]);
 g.screen=Screen::Playing; g.sync_system_keyboard(); assert!(!g.system_keyboard_up());
 assert!(!g.pad.menu.system_keyboard_hidden);
 g.screen=Screen::CommandBlock; g.sync_system_keyboard(); assert!(g.system_keyboard_up());
}
#[test] fn closing_editor_hides_keyboard_and_ignores_late_commit() {
 let mut g=Game::new(); g.screen=Screen::CommandBlock; g.sync_system_keyboard();
 g.screen=Screen::Playing; g.sync_system_keyboard(); g.ime_commit("late");
 assert_eq!(g.requests(),vec![true,false]); assert_eq!(g.command,"");
}
#[test] fn horizon_keyboard_routes_text_backspace_and_done_to_command_editor() {
 let mut g=Game::new(); g.screen=Screen::CommandBlock; g.pad.menu.osk=Some(());
 g.pad_osk_output(osk::Output::Text("say mobile".into())); assert_eq!(g.command,"say mobile");
 g.pad_osk_output(osk::Output::Backspace); assert_eq!(g.command,"say mobil");
 g.pad_osk_output(osk::Output::Enter); assert!(g.submitted); assert!(g.pad.menu.osk.is_none());
 assert!(g.screen==Screen::Playing);
}
#[test] fn modal_and_title_focus_override_underlying_command_editor() {
 let mut g=Game::new(); g.screen=Screen::CommandBlock; g.dialog=true;
 assert!(!g.field_focused()); assert!(!g.text_field_focused()); g.sync_system_keyboard();assert!(!g.system_keyboard_up());
 g.dialog_text=true;g.sync_system_keyboard();assert!(g.system_keyboard_up());
 g.dialog=false;g.dialog_text=false;g.title=Some(Title{focused:false});g.sync_system_keyboard();assert!(!g.system_keyboard_up());
}
#[test] fn ordinary_gameplay_and_non_ios_do_not_request_ios_keyboard() {
 let mut g=Game::new();g.sync_system_keyboard();assert!(g.requests().is_empty());
 g.ios=false;g.screen=Screen::CommandBlock;g.sync_system_keyboard();assert!(g.requests().is_empty());
 assert!(g.text_field_focused(),"desktop/Android IME focus remains available");
}
'''


class MobileCommandKeyboardTests(unittest.TestCase):
    def test_production_keyboard_focus_lifecycle_and_editor_routing(self):
        compiler = shutil.which('rustc')
        if compiler is None:
            self.skipTest('rustc is required for the production-method probe')
        with tempfile.TemporaryDirectory(prefix='horizon-command-keyboard-') as folder:
            folder = Path(folder)
            source = folder / 'probe.rs'
            source.write_text(program())
            binary = folder / 'probe'
            build = subprocess.run([compiler, '--edition=2024', '--test', str(source), '-o', str(binary)],
                                   capture_output=True, text=True, timeout=60)
            self.assertEqual(build.returncode, 0, build.stdout + build.stderr)
            run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn('6 passed', run.stdout)


if __name__ == '__main__':
    unittest.main()
