module dud.resolve.toolchain;

import std.array : array, front;
import std.algorithm.iteration : filter, map;
import std.algorithm.searching : all, find;
import std.typecons : nullable, Nullable;
import std.exception : enforce;
import std.format : format;

import dud.pkgdescription : Toolchain;
import dud.resolve.versionconfigurationtoolchain;
import dud.semver.setoperation;
import dud.semver.versionunion;
import dud.semver.versionrange : SetRelation;

@safe pure:

struct ToolchainVersionUnion {
	Toolchain tool;
	bool no;
	VersionUnion version_;
}

ToolchainVersionUnion dup(const(ToolchainVersionUnion) old) {
	return ToolchainVersionUnion(old.tool, old.no
			, old.version_.dup());
}

ToolchainVersionUnion invert(const(ToolchainVersionUnion) old) {
	return ToolchainVersionUnion(cast()old.tool, !old.no
			, dud.semver.setoperation.invert(old.version_));
}

private void testToolchainEqual(const(ToolchainVersionUnion) a
		, const(ToolchainVersionUnion) b, string file = __FILE__
		, int line = __LINE__)
{
	import std.exception : enforce;

	enforce(a.tool == b.tool, format("Both tools must be the same, but got "
				~ "a.tool %s, b.tool %s", a.tool, b.tool), file, line);
}

/** Tests if all elements in bs are allowed by an element in `as`.
* Allowed also means that no entry is present in `as`
*/
bool allowsAny(const(ToolchainVersionUnion)[] as
		, const(ToolchainVersionUnion)[] bs)
{
	return bs.map!(b => {
				auto other = as.find!(it => it.tool == b.tool);
				return other.empty
					? true
					: allowsAny(other.front, b);
			}())
			.all;
}

bool allowsAny(const(ToolchainVersionUnion) a, const(ToolchainVersionUnion) b) {
	testToolchainEqual(a, b);

	return a.no
		? false
		: dud.resolve.versionconfigurationtoolchain.allowsAny(a.version_
				, b.version_);
}

/** Tests if all elements in bs are allowed by an element in `as`.
* Allowed also means that no entry is present in `as`
*/
bool allowsAll(const(ToolchainVersionUnion)[] as
		, const(ToolchainVersionUnion)[] bs)
{
	return bs.map!(b => {
				auto other = as.find!(it => it.tool == b.tool);
				return other.empty
					? true
					: allowsAll(other.front, b);
			}())
			.all;
}

bool allowsAll(const(ToolchainVersionUnion) a, const(ToolchainVersionUnion) b) {
	testToolchainEqual(a, b);

	return a.no
		? false
		: dud.resolve.versionconfigurationtoolchain.allowsAll(a.version_
				, b.version_);
}

ToolchainVersionUnion intersectionOf(const(ToolchainVersionUnion) a,
		const(ToolchainVersionUnion) b)
{
	testToolchainEqual(a, b);

	return a.no || b.no
		? ToolchainVersionUnion(a.tool, true)
		: ToolchainVersionUnion(a.tool, false
				, dud.semver.setoperation.intersectionOf(a.version_
					, b.version_));
}

ToolchainVersionUnion[] intersectionOf(const(ToolchainVersionUnion)[] as
		, const(ToolchainVersionUnion)[] bs)
{
	return as.map!(a => {
				auto other = bs.find!(it => it.tool == a.tool);
				return other.empty
					? Nullable!(ToolchainVersionUnion).init
					: nullable(intersectionOf(a, other.front));
			}())
			.filter!(it => !it.isNull())
			.map!(it => it.get())
			.array;
}

/** Return if `a` is a subset of `b`, or if `a` and `b` are disjoint, or
if `a` and `b` overlap
*/
SetRelation relation(const(ToolchainVersionUnion) a
		, const(ToolchainVersionUnion) b)
{
	testToolchainEqual(a, b);

	if(b.no) {
		return SetRelation.disjoint;
	}

	return dud.resolve.versionconfigurationtoolchain.allowsAll(b.version_
			, a.version_)
		? SetRelation.subset
		: dud.resolve.versionconfigurationtoolchain.allowsAny(b.version_
				, a.version_)
			? SetRelation.overlapping
			: SetRelation.disjoint;
}
