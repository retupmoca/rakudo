role Perl6::Metamodel::Mixins {
    has $!is_mixin;
    has $!mixin_attribute;
    method set_is_mixin($obj) { $!is_mixin := 1 }
    method is_mixin($obj) { $!is_mixin }
    method set_mixin_attribute($obj, $attr) { $!mixin_attribute := $attr }
    method mixin_attribute($obj) { $!mixin_attribute }
    method flush_cache($obj) { }

    method mixin($obj, *@roles, :$need-mixin-attribute) {
        # Flush its cache as promised, otherwise outdated NFAs will stick around.
        self.flush_cache($obj) if !nqp::isnull($obj) || self.is_mixin($obj);
        # Work out a type name for the post-mixed-in role.
        my @role_names;
        for @roles { @role_names.push(~$_.HOW.name($_)) }
        my $new_name := self.name($obj) ~ '+{' ~
            nqp::join(',', @role_names) ~ '}';
        
        # Create new type, derive it from ourself and then add
        # all the roles we're mixing it.
        my $new_type := self.new_type(:name($new_name), :repr($obj.REPR));
        $new_type.HOW.set_is_mixin($new_type);
        $new_type.HOW.add_parent($new_type, $obj.WHAT);
        for @roles {
            $new_type.HOW.add_role($new_type, $_);
        }
        $new_type.HOW.compose($new_type);
        $new_type.HOW.set_boolification_mode($new_type,
            nqp::existskey($new_type.HOW.method_table($new_type), 'Bool') ?? 0 !!
                self.get_boolification_mode($obj));
        $new_type.HOW.publish_boolification_spec($new_type);

        # If needed, locate the mixin target attribute.
        if $need-mixin-attribute {
            my $found;
            for $new_type.HOW.attributes($new_type, :local) {
                if $_.has_accessor {
                    if $found {
                        $found := NQPMu;
                        last;
                    }
                    $found := $_;
                }
            }
            unless $found {
                my %ex := nqp::gethllsym('perl6', 'P6EX');
                if !nqp::isnull(%ex) && nqp::existskey(%ex, 'X::Role::Initialization') {
                    nqp::atkey(%ex, 'X::Role::Initialization')(@roles[0]);
                }
                else {
                    my $name := @roles[0].HOW.name(@roles[0]);
                    nqp::die("Can only supply an initialization value for a role if it has a single public attribute, but this is not the case for '$name'");
                }
            }
            $new_type.HOW.set_mixin_attribute($new_type, $found);
        }
        
        # If the original object was concrete, change its type by calling a
        # low level op. Otherwise, we just return the new type object
        nqp::isconcrete($obj) ?? nqp::rebless($obj, $new_type) !! $new_type
    }
    
    method mixin_base($obj) {
        for self.mro($obj) {
            unless $_.HOW.is_mixin($_) {
                return $_;
            }
        }
    }
}
