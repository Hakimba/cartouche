// SPDX-License-Identifier: GPL-3.0-or-later
package app.cartouche.core.launch

import app.cartouche.core.ContentUri
import app.cartouche.core.FileName
import app.cartouche.core.FilePath
import arrow.core.Either
import arrow.core.None
import arrow.core.Some
import io.kotest.assertions.arrow.core.shouldBeLeft
import io.kotest.assertions.arrow.core.shouldBeRight
import io.kotest.assertions.arrow.core.shouldBeSome
import io.kotest.matchers.ints.shouldBeGreaterThan
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.choice
import io.kotest.property.arbitrary.filter
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.map
import io.kotest.property.arbitrary.string
import io.kotest.property.checkAll
import kotlinx.coroutines.runBlocking
import org.junit.Test

class LaunchTemplateTest {
    private fun parse(template: String) = LaunchTemplate.parse(template).shouldBeRight()

    private fun resolve(template: String, file: GameFile = sdGame) = parse(template).resolve(file)

    private fun spec(template: String) = resolve(template).shouldBeRight()

    private fun parseError(template: String) = LaunchTemplate.parse(template).shouldBeLeft()

    // The three templates below are Daijishō player definitions (github.com/TapiocaFox/Daijishou, MIT).

    @Test
    fun `RetroArch template passes the path in extras and keeps spaces in one argument`() {
        val spec =
            spec(
                """-n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture
             -e ROM {file.path} -e LIBRETRO mgba
             -e CONFIGFILE /storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg""",
            )
        spec.targetPackage.map { it.value } shouldBe Some("com.retroarch.aarch64")
        spec.extras.map { it.key to it.value } shouldBe
            listOf(
                "ROM" to ExtraValue.Text("/storage/1A2B-3C4D/ROMs/ps2/Burnout 3 - Takedown (Europe).chd"),
                "LIBRETRO" to ExtraValue.Text("mgba"),
                "CONFIGFILE" to ExtraValue.Text("/storage/emulated/0/Android/data/com.retroarch.aarch64/files/retroarch.cfg"),
            )
        spec.grant shouldBe None
    }

    @Test
    fun `Dolphin template hands the game URI in an extra, and that URI is granted`() {
        val spec = spec("-n org.dolphinemu.dolphinemu/.ui.main.MainActivity -a android.intent.action.MAIN -e AutoStartFile {file.uri}")
        spec.component.map { it.packageName.value to it.className } shouldBe
            Some("org.dolphinemu.dolphinemu" to "org.dolphinemu.dolphinemu.ui.main.MainActivity")
        spec.grant shouldBe Some(sdGame.uri)
    }

    @Test
    fun `ARMSX2 template uses the data URI and activity switches`() {
        val spec = spec("-n com.armsx2/.Main -a android.intent.action.VIEW -d {file.uri} --activity-clear-task --activity-clear-top")
        spec.data shouldBe Some(GAME_URI)
        spec.switches shouldBe setOf(ActivitySwitch.CLEAR_TASK, ActivitySwitch.CLEAR_TOP)
    }

    @Test
    fun `typed extras and flags follow am`() {
        val spec =
            spec(
                """-n a.b/.C -f 0x4 --ez a t --ez b 0 --ez c TRUE --ei n 0x10 --el big -9 --ef ratio 1.5 --esa l 'a\,b,c' --esn e -f 8""",
            )
        spec.flags shouldBe 8
        spec.extras.map { it.value } shouldBe
            listOf(
                ExtraValue.Flag(true),
                ExtraValue.Flag(false),
                ExtraValue.Flag(true),
                ExtraValue.IntNumber(16),
                ExtraValue.LongNumber(-9),
                ExtraValue.FloatNumber(1.5f),
                ExtraValue.TextArray(listOf("a,b", "c")),
                ExtraValue.EmptyText,
            )
        resolve("-n a.b/.C --el big 0x10").shouldBeLeft() shouldBe TemplateError.InvalidValue("--el", "0x10")
    }

    @Test
    fun `an implicit intent has no target package`() {
        spec("-a android.intent.action.VIEW -d {file.uri}").targetPackage shouldBe None
    }

    @Test
    fun `quotes and escapes`() {
        LaunchTemplate.tokenize("""-e K 'a b' -e L "c \"d\" \\" x\ y ''""").shouldBeRight() shouldBe
            listOf("-e", "K", "a b", "-e", "L", "c \"d\" \\", "x y", "")
    }

    @Test
    fun `grammar errors are typed values`() {
        parseError("-n a.b/.C -e 'open") shouldBe TemplateError.UnclosedQuote
        parseError("-n a.b/.C \\") shouldBe TemplateError.DanglingEscape
        parseError("-e ROM x") shouldBe TemplateError.MissingTarget
        parseError("-n a.b/.C -e ROM") shouldBe TemplateError.MissingValue("-e")
        parseError("-n a.b/.C --weird") shouldBe TemplateError.UnknownOption("--weird")
        parseError("-n nopackage") shouldBe TemplateError.InvalidComponent("nopackage")
        parseError("-n 1a.b/.C") shouldBe TemplateError.InvalidComponent("1a.b/.C")
        parseError("-n a.b/.C -f nope") shouldBe TemplateError.InvalidValue("-f", "nope")
        resolve("-n a.b/.C -e X {tags.region}").shouldBeLeft() shouldBe TemplateError.UnknownPlaceholder("tags.region")
        resolve("-n a.b/.C --ez X maybe").shouldBeLeft() shouldBe TemplateError.InvalidValue("--ez", "maybe")
    }

    @Test
    fun `INV-E0-02 no content URI but the game's is handed where Android would grant it`() {
        resolve("-n a.b/.C -d {file.uri}.sav").shouldBeLeft() shouldBe TemplateError.ForeignUri("$GAME_URI.sav")
        resolve("-n a.b/.C --eu android.intent.extra.STREAM ' Content://other'").shouldBeLeft() shouldBe
            TemplateError.ForeignUri(" Content://other")
        spec("-n a.b/.C -e NOTE content://other -d file:///x").grant shouldBe None
        // Written literally, the game's URI would get no ClipData, and Android would grant the extra itself.
        resolve("-n a.b/.C -a android.media.action.IMAGE_CAPTURE --eu output $GAME_URI").shouldBeLeft() shouldBe
            TemplateError.ForeignUri(GAME_URI)
    }

    @Test
    fun `INV-E0-01 templates cannot grant URI permissions`() = runBlocking<Unit> {
        parseError("-n a.b/.C --grant-write-uri-permission") shouldBe TemplateError.ForbiddenOption("--grant-write-uri-permission")
        parseError("-n a.b/.C -f 0x2") shouldBe TemplateError.ForbiddenFlags(GrantFlags.WRITE)
        checkAll(Arb.int().filter { it and GrantFlags.ALL != 0 }) { flags ->
            parseError("-n a.b/.C -f $flags") shouldBe TemplateError.ForbiddenFlags(flags)
        }
    }

    @Test
    fun `INV-E0-02 only the game's own URI is granted, exactly when the launch depends on it`() = runBlocking<Unit> {
        var granted = 0
        forEveryResolvedTemplate { template, spec ->
            template.resolve(otherGame).onRight { other ->
                spec.grant shouldBe if (spec.copy(grant = None) != other.copy(grant = None)) Some(sdGame.uri) else None
            }
            if (spec.grant.isSome()) granted++
        }
        // Enough generated launches hand the game over for the law to be tested both ways.
        granted shouldBeGreaterThan 100
    }

    @Test
    fun `INV-E0-02 the data URI and URI extras are never a content URI other than the game's`() = runBlocking<Unit> {
        forEveryResolvedTemplate { _, spec ->
            val uris = spec.data.toList() + spec.extras.map { it.value }.filterIsInstance<ExtraValue.UriText>().map { it.value }
            uris.filter { it.trim().startsWith("content:", ignoreCase = true) }.forEach { it shouldBe GAME_URI }
        }
    }

    @Test
    fun `INV-E0-03 placeholder values are inserted verbatim in every kind of value`() = runBlocking<Unit> {
        val template = parse("-n a.b/.C -d {file.uri} -e ROM {file.path} --eu U {file.uri} --esa L x,{file.path},y")
        checkAll(Arb.string().map { "content://$it" }, Arb.string()) { uri, path ->
            val spec = template.resolve(GameFile(FileName("g"), ContentUri.parse(uri).shouldBeSome(), Some(FilePath(path)))).shouldBeRight()
            spec.data shouldBe Some(uri)
            spec.extras.map { it.value } shouldBe
                listOf(ExtraValue.Text(path), ExtraValue.UriText(uri), ExtraValue.TextArray(listOf("x", path, "y")))
        }
    }

    @Test
    fun `INV-E0-04 parsing and resolving are total`() = runBlocking<Unit> {
        checkAll(Arb.choice(templates, Arb.string())) { text -> LaunchTemplate.parse(text).onRight { it.resolve(sdGame) } }
    }

    @Test
    fun `INV-E0-05 quoted tokens tokenize back to themselves`() = runBlocking<Unit> {
        checkAll(Arb.list(Arb.string().filter { '\'' !in it })) { tokens ->
            LaunchTemplate.tokenize(tokens.joinToString(" ") { "'$it'" }).shouldBeRight() shouldBe tokens
        }
        checkAll(Arb.list(Arb.string())) { tokens ->
            val quoted = tokens.joinToString(" ") { "\"" + it.replace("\\", "\\\\").replace("\"", "\\\"") + "\"" }
            LaunchTemplate.tokenize(quoted).shouldBeRight() shouldBe tokens
        }
    }

    @Test
    fun `INV-E0-06 a template needing a path cannot launch a file that has none`() = runBlocking<Unit> {
        resolve("-n a.b/.C -e ROM {file.path}", sdGame.copy(path = None)).shouldBeLeft() shouldBe
            TemplateError.UnknownPlaceholder("file.path")
        // Whatever the template, a launch resolved without a path is the same with one: it never used it.
        forEveryResolvedTemplate(sdGame.copy(path = None)) { template, spec -> template.resolve(sdGame) shouldBe Either.Right(spec) }
    }
}
